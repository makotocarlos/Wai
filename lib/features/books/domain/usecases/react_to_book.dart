import '../entities/book_reaction.dart';
import '../repositories/books_repository.dart';

class ReactToBookParams {
  ReactToBookParams({
    required this.bookId,
    required this.isLike,
    this.delta = 1,
  });

  final String bookId;
  final bool isLike;
  final int delta;
}

class ReactToBook {
  ReactToBook(this._repository);

  final BooksRepository _repository;

  Future<BookReaction> call(ReactToBookParams params) {
    return _repository.reactToBook(
      bookId: params.bookId,
      isLike: params.isLike,
      delta: params.delta,
    );
  }
}
