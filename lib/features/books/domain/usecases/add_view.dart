import '../repositories/books_repository.dart';

class AddViewUseCase {
	const AddViewUseCase(this._repository);

	final BooksRepository _repository;

	Future<void> call({
		required String bookId,
		required String userId,
	}) {
		return _repository.addView(bookId: bookId, userId: userId);
	}
}
