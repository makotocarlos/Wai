import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class ReactToBookUseCase {
	const ReactToBookUseCase(this._repository);

	final BooksRepository _repository;

	Future<void> call({
		required String bookId,
		required String userId,
		required BookReactionType? reaction,
	}) {
		return _repository.reactToBook(
			bookId: bookId,
			userId: userId,
			reaction: reaction,
		);
	}
}
