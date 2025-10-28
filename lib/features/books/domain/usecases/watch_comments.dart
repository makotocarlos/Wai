import '../entities/comment_entity.dart';
import '../repositories/books_repository.dart';

class WatchComments {
  WatchComments(this._repository);

  final BooksRepository _repository;

  Stream<List<CommentEntity>> call(String bookId) {
    return _repository.watchComments(bookId);
  }
}
