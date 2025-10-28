import 'dart:io';

import '../entities/chapter_entity.dart';
import '../repositories/books_repository.dart';

class CreateBookParams {
  CreateBookParams({
    required this.title,
    required this.category,
    required this.chapters,
    required this.publishedChapterOrder,
    this.description,
    this.coverFile,
  });

  final String title;
  final String category;
  final List<ChapterEntity> chapters;
  final int publishedChapterOrder;
  final String? description;
  final File? coverFile;
}

class CreateBook {
  CreateBook(this._repository);

  final BooksRepository _repository;

  Future<void> call(CreateBookParams params) {
    return _repository.createBook(
      title: params.title,
      category: params.category,
      chapters: params.chapters,
      publishedChapterOrder: params.publishedChapterOrder,
      description: params.description,
      coverFile: params.coverFile,
    );
  }
}
