import 'package:equatable/equatable.dart';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_search_sort.dart';

enum SearchStatus { initial, loading, success, empty, failure }

enum SearchAiRole { user, assistant }

class SearchAiMessage extends Equatable {
  const SearchAiMessage._({
    required this.role,
    required this.content,
    this.books = const [],
  });

  const SearchAiMessage.user(String content)
      : this._(role: SearchAiRole.user, content: content);

  const SearchAiMessage.assistant({
    required String content,
    List<BookEntity> books = const [],
  }) : this._(role: SearchAiRole.assistant, content: content, books: books);

  final SearchAiRole role;
  final String content;
  final List<BookEntity> books;

  @override
  List<Object?> get props => [role, content, books];
}

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.results = const [],
    this.categories = const [],
    this.selectedCategory,
    this.sort = BookSearchSort.recent,
    this.query = '',
    this.errorMessage,
    this.isLoadingCategories = false,
    this.isAiProcessing = false,
    this.aiMessages = const [],
    this.isGeminiAvailable = false,
    this.isAiResult = false,
  });

  final SearchStatus status;
  final List<BookEntity> results;
  final List<String> categories;
  final String? selectedCategory;
  final BookSearchSort sort;
  final String query;
  final String? errorMessage;
  final bool isLoadingCategories;
  final bool isAiProcessing;
  final List<SearchAiMessage> aiMessages;
  final bool isGeminiAvailable;
  final bool isAiResult;

  SearchState copyWith({
    SearchStatus? status,
    List<BookEntity>? results,
    List<String>? categories,
    String? selectedCategory,
    bool clearCategory = false,
    BookSearchSort? sort,
    String? query,
    String? errorMessage,
    bool clearError = false,
    bool? isLoadingCategories,
    bool? isAiProcessing,
    List<SearchAiMessage>? aiMessages,
    bool? isGeminiAvailable,
    bool? isAiResult,
  }) {
    return SearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      categories: categories ?? this.categories,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      sort: sort ?? this.sort,
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isAiProcessing: isAiProcessing ?? this.isAiProcessing,
      aiMessages: aiMessages ?? this.aiMessages,
      isGeminiAvailable: isGeminiAvailable ?? this.isGeminiAvailable,
      isAiResult: isAiResult ?? this.isAiResult,
    );
  }

  @override
  List<Object?> get props => [
        status,
        results,
        categories,
        selectedCategory,
        sort,
        query,
        errorMessage,
        isLoadingCategories,
        isAiProcessing,
        aiMessages,
        isGeminiAvailable,
        isAiResult,
      ];
}
