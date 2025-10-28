import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class WatchBook {
  WatchBook(this._repository);

  final BooksRepository _repository;

  Stream<BookEntity> call(String bookId) {
    return _repository.watchBook(bookId);
  }
}
