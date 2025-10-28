import '../repositories/books_repository.dart';

class AddCommentParams {
  AddCommentParams({
    required this.bookId,
    required this.content,
    this.parentId,
  });

  final String bookId;
  final String content;
  final String? parentId;
}

class AddComment {
  AddComment(this._repository);

  final BooksRepository _repository;

  Future<void> call(AddCommentParams params) {
    return _repository.addComment(
      bookId: params.bookId,
      content: params.content,
      parentId: params.parentId,
    );
  }
}
