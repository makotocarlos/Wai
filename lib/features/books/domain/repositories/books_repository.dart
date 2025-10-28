import 'dart:io';

import '../entities/book_entity.dart';
import '../entities/book_reaction.dart';
import '../entities/chapter_entity.dart';
import '../entities/comment_entity.dart';

abstract class BooksRepository {
  Future<void> createBook({
    required String title,
    required String category,
    required List<ChapterEntity> chapters,
    required int publishedChapterOrder,
    String? description,
    File? coverFile,
  });

  Stream<List<BookEntity>> watchBooks();

  Stream<List<BookEntity>> watchUserBooks();

  Stream<BookEntity> watchBook(String bookId);

  Future<void> addComment({
    required String bookId,
    required String content,
    String? parentId,
  });

  Stream<List<CommentEntity>> watchComments(String bookId);

  Future<void> addChapterComment({
    required String bookId,
    required int chapterOrder,
    required String content,
    String? parentId,
  });

  Stream<List<CommentEntity>> watchChapterComments({
    required String bookId,
    required int chapterOrder,
  });

  Future<void> incrementBookViews(String bookId);

  Future<BookReaction> reactToBook({
    required String bookId,
    required bool isLike,
    int delta,
  });

  Future<BookReaction> getUserBookReaction(String bookId);

  Future<BookReaction> reactToComment({
    required String bookId,
    required String commentId,
    required bool isLike,
    int? chapterOrder,
  });

  Future<Map<String, BookReaction>> getUserCommentReactions({
    required String bookId,
    int? chapterOrder,
  });

  Future<void> updateBook({
    required String bookId,
    required String title,
    required String category,
    required List<ChapterEntity> chapters,
    required int publishedChapterOrder,
    String? description,
    File? coverFile,
    bool removeCover = false,
  });

  Future<void> deleteBook(String bookId);
}
