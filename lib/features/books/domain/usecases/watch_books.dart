import '../entities/book_entity.dart';
import '../repositories/books_repository.dart';

class WatchBooksUseCase {
	const WatchBooksUseCase(this._repository);

	final BooksRepository _repository;

	Stream<List<BookEntity>> call({String? userId}) {
		return _repository.watchBooks(userId: userId);
	}
}
