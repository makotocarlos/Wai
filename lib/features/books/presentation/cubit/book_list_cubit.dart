import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/usecases/watch_books.dart';
import 'book_list_state.dart';
import 'books_event_bus.dart';

class BookListCubit extends Cubit<BookListState> {
  BookListCubit({
    required WatchBooksUseCase watchBooks,
    UserEntity? user,
    bool onlyUserBooks = false,
    BooksEventBus? eventsBus,
  })  : assert(
          !onlyUserBooks || user != null,
          'User must be provided when onlyUserBooks is true',
        ),
        _watchBooks = watchBooks,
        _user = user,
        _onlyUserBooks = onlyUserBooks,
        _eventsBus = eventsBus,
        super(const BookListState()) {
    _eventsSubscription = _eventsBus?.stream.listen(_handleBookEvent);
  }

  final WatchBooksUseCase _watchBooks;
  final UserEntity? _user;
  final bool _onlyUserBooks;
  final BooksEventBus? _eventsBus;
  StreamSubscription? _subscription;
  StreamSubscription<BooksEvent>? _eventsSubscription;

  UserEntity? get user => _user;

  void start() {
    emit(state.copyWith(status: BookListStatus.loading, clearError: true));
    _subscription?.cancel();
    _subscription = _watchBooks(
      userId: _onlyUserBooks ? _user?.id : null,
    ).listen(
      (books) {
        final filteredBooks = _onlyUserBooks && _user != null
            ? books.where((book) => book.authorId == _user!.id).toList()
            : books;
        emit(state.copyWith(
          status: BookListStatus.success,
          books: filteredBooks,
          clearError: true,
        ));
      },
      onError: (_) {
        emit(state.copyWith(
          status: BookListStatus.failure,
          errorMessage: 'No se pudieron cargar los libros.',
        ));
      },
    );
  }

  /// Actualiza o inserta un libro en la lista inmediatamente.
  void upsertBook(BookEntity book) {
    final books = [...state.books];
    final index = books.indexWhere((element) => element.id == book.id);
    if (index >= 0) {
      books[index] = book;
    } else {
      books.insert(0, book);
    }

    emit(state.copyWith(
      status: BookListStatus.success,
      books: books,
      clearError: true,
    ));
  }

  void removeBook(String bookId) {
    final books =
        state.books.where((book) => book.id != bookId).toList(growable: false);

    emit(state.copyWith(
      status: BookListStatus.success,
      books: books,
      clearError: true,
    ));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _eventsSubscription?.cancel();
    return super.close();
  }

  void _handleBookEvent(BooksEvent event) {
    if (_onlyUserBooks && event.book.authorId != _user?.id) {
      return;
    }

    switch (event.type) {
      case BooksEventType.created:
      case BooksEventType.updated:
        upsertBook(event.book);
        break;
      case BooksEventType.deleted:
        removeBook(event.book.id);
        break;
    }
  }
}
