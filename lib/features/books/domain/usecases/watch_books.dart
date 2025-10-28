import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class WatchBooks {
  WatchBooks(this._repository);

  final BooksRepository _repository;

  Stream<List<BookEntity>> call() {
    return _repository.watchBooks();
  }
}
