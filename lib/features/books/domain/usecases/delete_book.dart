import '../repositories/books_repository.dart';

class DeleteBook {
  DeleteBook(this._repository);

  final BooksRepository _repository;

  Future<void> call(String bookId) {
    return _repository.deleteBook(bookId);
  }
}
