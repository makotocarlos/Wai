import '../repositories/books_repository.dart';

class AddChapterCommentParams {
  AddChapterCommentParams({
    required this.bookId,
    required this.chapterOrder,
    required this.content,
    this.parentId,
  });

  final String bookId;
  final int chapterOrder;
  final String content;
  final String? parentId;
}

class AddChapterComment {
  AddChapterComment(this._repository);

  final BooksRepository _repository;

  Future<void> call(AddChapterCommentParams params) {
    return _repository.addChapterComment(
      bookId: params.bookId,
      chapterOrder: params.chapterOrder,
      content: params.content,
      parentId: params.parentId,
    );
  }
}
