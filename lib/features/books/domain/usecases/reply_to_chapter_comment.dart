import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

class ReplyToChapterCommentUseCase {
  const ReplyToChapterCommentUseCase(this._repository);

  final BooksRepository _repository;

  Future<void> call({
    required String chapterId,
    required String parentCommentId,
    required CommentEntity reply,
  }) {
    return _repository.replyToChapterComment(
      chapterId: chapterId,
      parentCommentId: parentCommentId,
      reply: reply,
    );
  }
}
