import '../entities/book_reaction.dart';
import '../repositories/books_repository.dart';

class GetBookReaction {
	GetBookReaction(this._repository);

	final BooksRepository _repository;

	Future<BookReaction> call(String bookId) {
		return _repository.getUserBookReaction(bookId);
	}
}
