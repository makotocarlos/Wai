import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class WatchUserBooks {
  WatchUserBooks(this._repository);

  final BooksRepository _repository;

  Stream<List<BookEntity>> call() {
    return _repository.watchUserBooks();
  }
}
