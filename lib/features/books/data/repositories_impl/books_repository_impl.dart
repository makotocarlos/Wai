import 'dart:io';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';
import '../datasources/books_remote_datasource.dart';

class BooksRepositoryImpl implements BooksRepository {
  BooksRepositoryImpl({required BooksRemoteDataSource remote})
      : _remote = remote;

  final BooksRemoteDataSource _remote;

  @override
  Future<void> createBook({
    required String title,
    required String category,
    required List<ChapterEntity> chapters,
    required int publishedChapterOrder,
    String? description,
    File? coverFile,
  }) {
    return _remote.createBook(
      title: title,
      category: category,
      chapters: chapters,
      publishedChapterOrder: publishedChapterOrder,
      description: description,
      coverFile: coverFile,
    );
  }

  @override
  Stream<List<BookEntity>> watchBooks() {
    return _remote.watchBooks();
  }

  @override
  Stream<List<BookEntity>> watchUserBooks() {
    return _remote.watchUserBooks();
  }

  @override
  Stream<BookEntity> watchBook(String bookId) {
    return _remote.watchBook(bookId);
  }

  @override
  Future<void> addComment({
    required String bookId,
    required String content,
    String? parentId,
  }) {
    return _remote.addComment(
      bookId: bookId,
      content: content,
      parentId: parentId,
    );
  }

  @override
  Stream<List<CommentEntity>> watchComments(String bookId) {
    return _remote.watchComments(bookId);
  }

  @override
  Future<void> addChapterComment({
    required String bookId,
    required int chapterOrder,
    required String content,
    String? parentId,
  }) {
    return _remote.addChapterComment(
      bookId: bookId,
      chapterOrder: chapterOrder,
      content: content,
      parentId: parentId,
    );
  }

  @override
  Stream<List<CommentEntity>> watchChapterComments({
    required String bookId,
    required int chapterOrder,
  }) {
    return _remote.watchChapterComments(
      bookId: bookId,
      chapterOrder: chapterOrder,
    );
  }

  @override
  Future<void> incrementBookViews(String bookId) {
    return _remote.incrementBookViews(bookId);
  }

  @override
  Future<BookReaction> reactToBook({
    required String bookId,
    required bool isLike,
    int delta = 1,
  }) {
    return _remote.reactToBook(
      bookId: bookId,
      isLike: isLike,
      delta: delta,
    );
  }

  @override
  Future<BookReaction> getUserBookReaction(String bookId) {
    return _remote.getUserBookReaction(bookId);
  }

  @override
  Future<BookReaction> reactToComment({
    required String bookId,
    required String commentId,
    required bool isLike,
    int? chapterOrder,
  }) {
    return _remote.reactToComment(
      bookId: bookId,
      commentId: commentId,
      isLike: isLike,
      chapterOrder: chapterOrder,
    );
  }

  @override
  Future<Map<String, BookReaction>> getUserCommentReactions({
    required String bookId,
    int? chapterOrder,
  }) {
    return _remote.getUserCommentReactions(
      bookId: bookId,
      chapterOrder: chapterOrder,
    );
  }

  @override
  Future<void> updateBook({
    required String bookId,
    required String title,
    required String category,
    required List<ChapterEntity> chapters,
    required int publishedChapterOrder,
    String? description,
    File? coverFile,
    bool removeCover = false,
  }) {
    return _remote.updateBook(
      bookId: bookId,
      title: title,
      category: category,
      chapters: chapters,
      publishedChapterOrder: publishedChapterOrder,
      description: description,
      coverFile: coverFile,
      removeCover: removeCover,
    );
  }

  @override
  Future<void> deleteBook(String bookId) {
    return _remote.deleteBook(bookId);
  }
}
