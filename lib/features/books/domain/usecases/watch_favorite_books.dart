import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class WatchFavoriteBooksUseCase {
  const WatchFavoriteBooksUseCase(this._repository);

  final BooksRepository _repository;

  Stream<List<BookEntity>> call({required String userId}) {
    return _repository.watchFavoriteBooks(userId: userId);
  }
}
