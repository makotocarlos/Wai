import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

/// Use Case: Responder a un comentario existente (YouTube-style)
class ReplyToCommentUseCase {
  ReplyToCommentUseCase(this._repository);

  final BooksRepository _repository;

  Future<void> call({
    required String bookId,
    required String parentCommentId,
    required CommentEntity reply,
  }) async {
    // Validaciones
    if (reply.content.trim().isEmpty) {
      throw ArgumentError('El contenido de la respuesta no puede estar vacío');
    }

    if (reply.parentCommentId != parentCommentId) {
      throw ArgumentError('El parentCommentId del reply no coincide');
    }

    await _repository.replyToComment(
      bookId: bookId,
      parentCommentId: parentCommentId,
      reply: reply,
    );
  }
}
