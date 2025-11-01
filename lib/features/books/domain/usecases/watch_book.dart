import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class WatchBookUseCase {
	const WatchBookUseCase(this._repository);

	final BooksRepository _repository;

	Stream<BookEntity> call({
		required String bookId,
		required String userId,
	}) {
		return _repository.watchBook(bookId: bookId, userId: userId);
	}
}
