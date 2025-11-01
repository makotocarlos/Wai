import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

class WatchCommentsUseCase {
	const WatchCommentsUseCase(this._repository);

	final BooksRepository _repository;

	Stream<List<CommentEntity>> call(String bookId, {String? userId}) {
		return _repository.watchComments(bookId, userId: userId);
	}
}
