import '../entities/book_reaction.dart';
import '../repositories/books_repository.dart';

class ReactToCommentParams {
  ReactToCommentParams({
    required this.bookId,
    required this.commentId,
    required this.isLike,
    this.chapterOrder,
  });

  final String bookId;
  final String commentId;
  final bool isLike;
  final int? chapterOrder;
}

class ReactToComment {
  ReactToComment(this._repository);

  final BooksRepository _repository;

  Future<BookReaction> call(ReactToCommentParams params) {
    return _repository.reactToComment(
      bookId: params.bookId,
      commentId: params.commentId,
      isLike: params.isLike,
      chapterOrder: params.chapterOrder,
    );
  }
}
