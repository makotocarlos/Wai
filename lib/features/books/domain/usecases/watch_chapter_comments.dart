import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

/// Use Case: Observar comentarios de un capítulo específico
class WatchChapterCommentsUseCase {
  WatchChapterCommentsUseCase(this._repository);

  final BooksRepository _repository;

  Stream<List<CommentEntity>> call(String chapterId, {String? userId}) {
    return _repository.watchChapterComments(chapterId, userId: userId);
  }
}
