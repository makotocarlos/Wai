import '../repositories/books_repository.dart';

class IncrementBookViews {
  IncrementBookViews(this._repository);

  final BooksRepository _repository;

  Future<void> call(String bookId) {
    return _repository.incrementBookViews(bookId);
  }
}
