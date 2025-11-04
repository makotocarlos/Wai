import '../entities/book_entity.dart';
import '../entities/book_search_sort.dart';
import '../repositories/books_repository.dart';

class SearchBooksUseCase {
  SearchBooksUseCase(this._repository);

  final BooksRepository _repository;

  Future<List<BookEntity>> call({
    String? query,
    String? category,
    BookSearchSort sortBy = BookSearchSort.recent,
    int limit = 40,
    String? currentUserId,
  }) {
    return _repository.searchBooks(
      query: query,
      category: category,
      sortBy: sortBy,
      limit: limit,
      currentUserId: currentUserId,
    );
  }
}
