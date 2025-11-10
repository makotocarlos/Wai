import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_search_sort.dart';
import '../../domain/usecases/get_book_categories.dart';
import '../../domain/usecases/search_books.dart';
import '../../domain/usecases/watch_books.dart';
import '../../domain/usecases/watch_favorite_books.dart';
import '../../../../services/ai/gemini_search_service.dart';
import 'books_event_bus.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required SearchBooksUseCase searchBooks,
    required GetBookCategoriesUseCase getBookCategories,
    required WatchFavoriteBooksUseCase watchFavoriteBooks,
    required WatchBooksUseCase watchUserBooks,
    required GeminiSearchService geminiSearchService,
    required BooksEventBus booksEventBus,
  })  : _searchBooks = searchBooks,
        _getBookCategories = getBookCategories,
        _watchFavoriteBooks = watchFavoriteBooks,
        _watchUserBooks = watchUserBooks,
        _geminiSearchService = geminiSearchService,
        _booksEventBus = booksEventBus,
        super(const SearchState());

  final SearchBooksUseCase _searchBooks;
  final GetBookCategoriesUseCase _getBookCategories;
  final WatchFavoriteBooksUseCase _watchFavoriteBooks;
  final WatchBooksUseCase _watchUserBooks;
  final GeminiSearchService _geminiSearchService;
  final BooksEventBus _booksEventBus;

  Timer? _debounce;
  String? _userId;
  List<BookEntity> _cachedFavorites = const [];
  List<BookEntity> _cachedUserBooks = const [];
  bool _userContextLoaded = false;
  StreamSubscription<BooksEvent>? _booksEventSub;
  bool _pendingEventRefresh = false;

  void initialize({UserEntity? user}) {
    _userId = user?.id;
    emit(state.copyWith(isGeminiAvailable: _geminiSearchService.isConfigured));
    _booksEventSub ??= _booksEventBus.stream.listen(_handleBooksEvent);
    _loadCategories();
    _performSearch(showLoading: true);
  }

  void updateQuery(String value) {
    emit(state.copyWith(query: value, isAiResult: false));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(showLoading: true);
    });
  }

  void changeCategory(String? category) {
    final normalized = category == null || category.isEmpty ? null : category;
    emit(state.copyWith(
      selectedCategory: normalized,
      isAiResult: false,
    ));
    _performSearch(showLoading: true);
  }

  void changeSort(BookSearchSort sort) {
    if (state.sort == sort) {
      return;
    }
    emit(state.copyWith(sort: sort, isAiResult: false));
    _performSearch(showLoading: true);
  }

  void clearSearch() {
    emit(state.copyWith(
      query: '',
      clearCategory: true,
      sort: BookSearchSort.recent,
      isAiResult: false,
    ));
    _performSearch(showLoading: true);
  }

  Future<void> refresh() async {
    await _performSearch(showLoading: true);
  }

  Future<void> sendAiPrompt(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final updatedMessages = [
      ...state.aiMessages,
      SearchAiMessage.user(trimmed),
    ];
    emit(state.copyWith(
      aiMessages: updatedMessages,
      isAiProcessing: true,
      clearError: true,
    ));

    try {
      await _ensureUserContext();
      var candidates = await _searchBooks(
        query: trimmed,
        category: state.selectedCategory,
        sortBy: state.sort,
        limit: 50,
        currentUserId: _userId,
      );

      if (candidates.isEmpty) {
        // Si la busqueda directa no devuelve nada, usamos un lote amplio para que la IA
        // pueda recomendar desde el catalogo general.
        candidates = await _searchBooks(
          query: null,
          category: state.selectedCategory,
          sortBy: state.sort,
          limit: 50,
          currentUserId: _userId,
        );
      }

      final result = await _geminiSearchService.generateRecommendation(
        prompt: trimmed,
        candidates: candidates,
        favoriteBooks: _cachedFavorites,
        userBooks: _cachedUserBooks,
      );

      final bookIndex = <String, BookEntity>{};
      for (final book in [
        ...candidates,
        ..._cachedFavorites,
        ..._cachedUserBooks,
      ]) {
        bookIndex.putIfAbsent(book.id, () => book);
      }

      final recommended = result.bookIds
          .map((id) => bookIndex[id])
          .whereType<BookEntity>()
          .toList();

      final assistantMessage = SearchAiMessage.assistant(
        content: result.message.isEmpty
            ? 'Esto es lo que pude encontrar por ahora.'
            : result.message,
        books: recommended,
      );

      final newResults = recommended.isEmpty ? candidates : recommended;
      final newStatus =
          newResults.isEmpty ? SearchStatus.empty : SearchStatus.success;

      emit(state.copyWith(
        aiMessages: [...updatedMessages, assistantMessage],
        isAiProcessing: false,
        results: newResults,
        status: newStatus,
        clearError: true,
        isAiResult: true,
      ));
    } on GeminiNotConfiguredException {
      emit(state.copyWith(
        isAiProcessing: false,
        errorMessage:
            'Configura la variable GEMINI_API_KEY para usar la busqueda con IA.',
      ));
    } on GeminiSearchFailure catch (error) {
      emit(state.copyWith(
        isAiProcessing: false,
        errorMessage: error.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        isAiProcessing: false,
        errorMessage: 'Ocurrio un error al procesar la solicitud de IA.',
      ));
    }
  }

  Future<void> _loadCategories() async {
    emit(state.copyWith(isLoadingCategories: true));
    try {
      final categories = await _getBookCategories();
      emit(state.copyWith(
        categories: categories,
        isLoadingCategories: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingCategories: false));
    }
  }

  Future<void> _performSearch({bool showLoading = false}) async {
    _debounce?.cancel();

    if (showLoading) {
      emit(state.copyWith(
        status: SearchStatus.loading,
        clearError: true,
        isAiResult: false,
      ));
    }

    try {
      final results = await _searchBooks(
        query: state.query.trim().isEmpty ? null : state.query.trim(),
        category: state.selectedCategory,
        sortBy: state.sort,
        currentUserId: _userId,
      );

      if (results.isEmpty) {
        emit(state.copyWith(
          status: SearchStatus.empty,
          results: const [],
          clearError: true,
          isAiResult: false,
        ));
        return;
      }

      emit(state.copyWith(
        status: SearchStatus.success,
        results: results,
        clearError: true,
        isAiResult: false,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: 'No se pudo completar la busqueda. Intentalo mas tarde.',
        isAiResult: false,
      ));
    }
  }

  Future<void> _ensureUserContext() async {
    if (_userId == null || _userContextLoaded) {
      return;
    }

    try {
      _cachedFavorites = await _watchFavoriteBooks(userId: _userId!).first;
      _cachedUserBooks = await _watchUserBooks(userId: _userId!).first;
    } catch (_) {
      _cachedFavorites = const [];
      _cachedUserBooks = const [];
    } finally {
      _userContextLoaded = true;
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _booksEventSub?.cancel();
    return super.close();
  }

  void _handleBooksEvent(BooksEvent event) {
    // Manejar creación y actualización
    if (event.type == BooksEventType.created ||
        event.type == BooksEventType.updated) {
      if (_userId != null && event.book.authorId == _userId) {
        final existingIndex =
            _cachedUserBooks.indexWhere((book) => book.id == event.book.id);
        if (existingIndex >= 0) {
          final updated = [..._cachedUserBooks];
          updated[existingIndex] = event.book;
          _cachedUserBooks = updated;
        } else {
          _cachedUserBooks = [event.book, ..._cachedUserBooks];
        }
      }

      if (_pendingEventRefresh) {
        return;
      }

      _pendingEventRefresh = true;
      unawaited(_performSearch(showLoading: false).whenComplete(() {
        _pendingEventRefresh = false;
      }));
    }
    
    // 🔥 Manejar eliminación
    if (event.type == BooksEventType.deleted) {
      print('🔍 [SearchCubit] Libro eliminado detectado: ${event.book.id}');
      
      // Eliminar de caché de libros del usuario
      if (_userId != null && event.book.authorId == _userId) {
        _cachedUserBooks = _cachedUserBooks
            .where((book) => book.id != event.book.id)
            .toList();
        print('🔍 [SearchCubit] Eliminado de _cachedUserBooks');
      }
      
      // Eliminar de favoritos
      _cachedFavorites = _cachedFavorites
          .where((book) => book.id != event.book.id)
          .toList();
      
      // Eliminar de resultados de búsqueda actuales
      final updatedResults = state.results
          .where((book) => book.id != event.book.id)
          .toList();
      
      print('🔍 [SearchCubit] Actualizando resultados de búsqueda');
      print('   - Antes: ${state.results.length} libros');
      print('   - Después: ${updatedResults.length} libros');
      
      emit(state.copyWith(
        results: updatedResults,
      ));
    }
  }
}
