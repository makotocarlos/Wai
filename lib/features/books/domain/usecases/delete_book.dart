import '../repositories/books_repository.dart';

class DeleteBookUseCase {
	const DeleteBookUseCase(this._repository);

	final BooksRepository _repository;

	Future<void> call({required String bookId}) {
		return _repository.deleteBook(bookId: bookId);
	}
}
