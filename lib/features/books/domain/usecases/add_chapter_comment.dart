import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

/// Use Case: Agregar comentario a un capítulo específico
class AddChapterCommentUseCase {
  AddChapterCommentUseCase(this._repository);

  final BooksRepository _repository;

  Future<void> call({
    required String chapterId,
    required CommentEntity comment,
  }) async {
    await _repository.addChapterComment(
      chapterId: chapterId,
      comment: comment,
    );
  }
}
