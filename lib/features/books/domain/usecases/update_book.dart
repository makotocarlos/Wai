import 'dart:io';

import '../entities/chapter_entity.dart';
import '../repositories/books_repository.dart';

class UpdateBookParams {
  const UpdateBookParams({
    required this.bookId,
    required this.title,
    required this.category,
    required this.chapters,
    required this.publishedChapterOrder,
    this.description,
    this.coverFile,
    this.removeCover = false,
  });

  final String bookId;
  final String title;
  final String category;
  final List<ChapterEntity> chapters;
  final int publishedChapterOrder;
  final String? description;
  final File? coverFile;
  final bool removeCover;
}

class UpdateBook {
  UpdateBook(this._repository);

  final BooksRepository _repository;

  Future<void> call(UpdateBookParams params) {
    return _repository.updateBook(
      bookId: params.bookId,
      title: params.title,
      category: params.category,
      chapters: params.chapters,
      publishedChapterOrder: params.publishedChapterOrder,
      description: params.description,
      coverFile: params.coverFile,
      removeCover: params.removeCover,
    );
  }
}
