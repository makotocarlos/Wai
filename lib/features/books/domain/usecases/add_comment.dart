import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

class AddCommentUseCase {
	const AddCommentUseCase(this._repository);

	final BooksRepository _repository;

	Future<void> call({
		required String bookId,
		required CommentEntity comment,
	}) {
		return _repository.addComment(bookId: bookId, comment: comment);
	}
}
