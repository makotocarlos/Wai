import '../entities/book_reaction.dart';
import '../repositories/books_repository.dart';

class GetCommentReactionsParams {
  const GetCommentReactionsParams({
    required this.bookId,
    this.chapterOrder,
  });

  final String bookId;
  final int? chapterOrder;
}

class GetCommentReactions {
  GetCommentReactions(this._repository);

  final BooksRepository _repository;

  Future<Map<String, BookReaction>> call(GetCommentReactionsParams params) {
    return _repository.getUserCommentReactions(
      bookId: params.bookId,
      chapterOrder: params.chapterOrder,
    );
  }
}
