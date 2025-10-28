import 'dart:io';

import '../../domain/entities/chapter_entity.dart';

class BookComposerSubmission {
  const BookComposerSubmission({
    required this.title,
    required this.category,
    required this.chapters,
    required this.publishedChapterOrder,
    this.bookId,
    this.description,
    this.coverFile,
    this.removeCover = false,
  });

  final String? bookId;
  final String title;
  final String category;
  final List<ChapterEntity> chapters;
  final int publishedChapterOrder;
  final String? description;
  final File? coverFile;
  final bool removeCover;
}
