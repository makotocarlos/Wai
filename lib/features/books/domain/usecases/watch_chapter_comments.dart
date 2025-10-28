import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

class WatchChapterCommentsParams {
  WatchChapterCommentsParams({
    required this.bookId,
    required this.chapterOrder,
  });

  final String bookId;
  final int chapterOrder;
}

class WatchChapterComments {
  WatchChapterComments(this._repository);

  final BooksRepository _repository;

  Stream<List<CommentEntity>> call(WatchChapterCommentsParams params) {
    return _repository.watchChapterComments(
      bookId: params.bookId,
      chapterOrder: params.chapterOrder,
    );
  }
}
