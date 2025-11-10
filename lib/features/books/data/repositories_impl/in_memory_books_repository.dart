import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_search_sort.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';

class InMemoryBooksRepository implements BooksRepository {
  InMemoryBooksRepository();

  final Map<String, BookEntity> _books = {};
  final Map<String, List<CommentEntity>> _comments = {};
  final Map<String, List<CommentEntity>> _chapterComments =
      {}; // Comentarios de capítulos
  final Map<String, Set<String>> _viewsByBook = {};
  final Map<String, Map<String, BookReactionType>> _reactionsByBook = {};
  final Map<String, Set<String>> _favoritesByBook = {};
  final Map<String, StreamController<List<BookEntity>>> _favoriteControllers =
      {};

  final StreamController<List<BookEntity>> _booksController =
      StreamController<List<BookEntity>>.broadcast();
  final Map<String, StreamController<BookEntity>> _bookControllers = {};
  final Map<String, StreamController<List<CommentEntity>>> _commentControllers =
      {};
  final Map<String, StreamController<List<CommentEntity>>>
      _chapterCommentControllers =
      {}; // Controllers para comentarios de capítulos

  @override
  Stream<List<BookEntity>> watchBooks({String? userId}) {
    _emitBooks();
    return _booksController.stream;
  }

  @override
  Stream<BookEntity> watchBook({
    required String bookId,
    required String userId,
  }) {
    _bookControllers.putIfAbsent(
      bookId,
      () => StreamController<BookEntity>.broadcast(),
    );
    final controller = _bookControllers[bookId]!;
    final book = _books[bookId];
    if (book != null) {
      controller.add(_withUserState(book, userId));
    }
    return controller.stream;
  }

  @override
  Future<BookEntity> createBook({
    required String authorId,
    required String authorName,
    required String title,
    required String category,
    required String description,
    required List<ChapterEntity> chapters,
    required int publishedChapterIndex,
    String? coverPath,
  }) async {
    final now = DateTime.now();
    final id = 'book_${now.microsecondsSinceEpoch}';
    final sanitizedChapters = [...chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    final book = BookEntity(
      id: id,
      authorId: authorId,
      authorName: authorName,
      title: title,
      category: category,
      description: description,
      createdAt: now,
      coverPath: coverPath,
      chapters: UnmodifiableListView(sanitizedChapters),
      publishedChapterIndex: publishedChapterIndex,
    );
    _books[id] = book;
    _comments[id] = [];
    _viewsByBook[id] = <String>{};
    _reactionsByBook[id] = <String, BookReactionType>{};
    _favoritesByBook[id] = <String>{};
    _emitBooks();
    _emitBook(book, null);
    return book;
  }

  @override
  Future<void> addView({
    required String bookId,
    required String userId,
  }) async {
    final book = _books[bookId];
    if (book == null) return;
    final viewers = _viewsByBook[bookId] ?? <String>{};
    if (!viewers.contains(userId)) {
      viewers.add(userId);
      _viewsByBook[bookId] = viewers;
      _books[bookId] = book.copyWith(viewCount: viewers.length);
      _emitBooks();
      _emitBook(_books[bookId]!, userId);
    }
  }

  @override
  Future<void> reactToBook({
    required String bookId,
    required String userId,
    required BookReactionType? reaction,
  }) async {
    final book = _books[bookId];
    if (book == null) return;
    final reactions = _reactionsByBook[bookId] ?? <String, BookReactionType>{};
    if (reaction == null) {
      reactions.remove(userId);
    } else {
      reactions[userId] = reaction;
    }
    _reactionsByBook[bookId] = reactions;

    final likeCount = reactions.values
        .where((value) => value == BookReactionType.like)
        .length;
    final dislikeCount = reactions.values
        .where((value) => value == BookReactionType.dislike)
        .length;

    _books[bookId] = book.copyWith(
      likeCount: likeCount,
      dislikeCount: dislikeCount,
    );
    _emitBooks();
    _emitBook(_books[bookId]!, userId);
  }

  @override
  Future<void> toggleFavorite({
    required String bookId,
    required String userId,
  }) async {
    final book = _books[bookId];
    if (book == null) return;

    final favorites = _favoritesByBook.putIfAbsent(bookId, () => <String>{});
    if (favorites.contains(userId)) {
      favorites.remove(userId);
    } else {
      favorites.add(userId);
    }

    final updatedBook = book.copyWith(favoritesCount: favorites.length);
    _books[bookId] = updatedBook;
    _favoritesByBook[bookId] = favorites;

    _emitBooks();
    _emitBook(updatedBook, userId);
    _emitFavoritesForUser(userId);
  }

  @override
  Future<String> uploadBookCover({
    required String authorId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final sanitized = fileExtension.replaceAll('.', '').toLowerCase();
    final extension = sanitized.isEmpty ? 'jpg' : sanitized;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'memory://$authorId/cover_$timestamp.$extension';
  }

  @override
  Future<List<BookEntity>> searchBooks({
    String? query,
    String? category,
    BookSearchSort sortBy = BookSearchSort.recent,
    int limit = 40,
    String? currentUserId,
  }) async {
    var results = _books.values
        .map((book) =>
            currentUserId == null ? book : _withUserState(book, currentUserId))
        .toList(growable: false);

    final trimmedCategory = category?.trim();
    if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
      final normalized = trimmedCategory.toLowerCase();
      results = results
          .where((book) => book.category.toLowerCase() == normalized)
          .toList(growable: false);
    }

    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      final normalized = trimmedQuery.toLowerCase();
      results = results
          .where(
            (book) =>
                book.title.toLowerCase().contains(normalized) ||
                book.authorName.toLowerCase().contains(normalized) ||
                book.category.toLowerCase().contains(normalized),
          )
          .toList(growable: false);
    }

    switch (sortBy) {
      case BookSearchSort.recent:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case BookSearchSort.mostViewed:
        results.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case BookSearchSort.mostLiked:
        results.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
    }

    if (limit > 0 && results.length > limit) {
      results = results.take(limit).toList(growable: false);
    }

    return results;
  }

  @override
  Future<List<String>> fetchCategories() async {
    final categories = <String, String>{};
    for (final book in _books.values) {
      final raw = book.category.trim();
      if (raw.isEmpty) {
        continue;
      }
      final key = raw.toLowerCase();
      categories.putIfAbsent(key, () => raw);
    }
    final keys = categories.keys.toList()..sort();
    return keys.map((key) => categories[key]!).toList(growable: false);
  }

  @override
  Future<void> addComment({
    required String bookId,
    required CommentEntity comment,
  }) async {
    final list = _comments.putIfAbsent(bookId, () => <CommentEntity>[]);
    list.add(comment);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _commentControllers[bookId]?.add(UnmodifiableListView(list));
  }

  @override
  Future<void> replyToComment({
    required String bookId,
    required String parentCommentId,
    required CommentEntity reply,
  }) async {
    final list = _comments.putIfAbsent(bookId, () => <CommentEntity>[]);
    list.add(reply);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Construir árbol y emitir
    final tree = _buildCommentTree(list);
    _commentControllers[bookId]?.add(UnmodifiableListView(tree));
  }

  @override
  Stream<List<CommentEntity>> watchComments(String bookId, {String? userId}) {
    _commentControllers.putIfAbsent(
      bookId,
      () => StreamController<List<CommentEntity>>.broadcast(),
    );
    final controller = _commentControllers[bookId]!;
    final existing = _comments[bookId];
    if (existing != null) {
      final tree = _buildCommentTree(existing);
      controller.add(UnmodifiableListView(tree));
    }
    return controller.stream;
  }

  /// Construye árbol de comentarios (root + replies anidadas)
  List<CommentEntity> _buildCommentTree(List<CommentEntity> comments) {
    // 1. Mapear todos los comentarios
    final allComments = <String, CommentEntity>{};
    for (final comment in comments) {
      allComments[comment.id] = comment;
    }

    // 2. Construir árbol: asignar replies a sus padres
    final rootComments = <CommentEntity>[];

    for (final comment in allComments.values) {
      if (comment.isRootComment) {
        // Comentario raíz
        rootComments.add(comment);
      } else {
        // Es una reply, agregarlo a su padre
        final parentId = comment.parentCommentId!;
        final parent = allComments[parentId];

        if (parent != null) {
          // Actualizar lista de replies del padre
          final updatedReplies = List<CommentEntity>.from(parent.replies)
            ..add(comment);

          allComments[parentId] = parent.copyWith(
            replies: updatedReplies,
            replyCount: updatedReplies.length,
          );
        }
      }
    }

    // 3. Retornar solo comentarios raíz (ya contienen sus replies)
    return rootComments
        .map((root) => allComments[root.id]!) // Obtener versión actualizada
        .toList();
  }

  void _emitBooks() {
    final books = _books.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _booksController.add(UnmodifiableListView(books));
  }

  void _emitBook(BookEntity book, String? userId) {
    final controller = _bookControllers[book.id];
    if (controller == null) return;
    controller.add(_withUserState(book, userId));
  }

  void _emitFavoritesForUser(String userId) {
    final controller = _favoriteControllers[userId];
    if (controller == null) return;

    final favoriteBooks = _books.values
        .where((book) => (_favoritesByBook[book.id] ?? {}).contains(userId))
        .map((book) => _withUserState(book, userId))
        .toList(growable: false);

    controller.add(favoriteBooks);
  }

  BookEntity _withUserState(BookEntity book, String? userId) {
    if (userId == null) {
      return book.copyWith(
        userReaction: null,
        isFavorited: false,
      );
    }
    final reaction = _reactionsByBook[book.id]?[userId];
    final favorites = _favoritesByBook[book.id] ?? const <String>{};
    final isFavorited = favorites.contains(userId);
    return book.copyWith(
      userReaction: reaction,
      isFavorited: isFavorited,
    );
  }

  @override
  Stream<List<BookEntity>> watchFavoriteBooks({required String userId}) {
    _favoriteControllers.putIfAbsent(
      userId,
      () => StreamController<List<BookEntity>>.broadcast(),
    );

    final controller = _favoriteControllers[userId]!;

    // Emit current favorites
    _emitFavoritesForUser(userId);

    return controller.stream;
  }

  void dispose() {
    _booksController.close();
    for (final controller in _bookControllers.values) {
      controller.close();
    }
    for (final controller in _commentControllers.values) {
      controller.close();
    }
    for (final controller in _chapterCommentControllers.values) {
      controller.close();
    }
  }

  // ===== Métodos de Comentarios de Capítulos =====

  @override
  Future<void> addChapterComment({
    required String chapterId,
    required CommentEntity comment,
  }) async {
    final list = _chapterComments[chapterId] ?? [];
    list.add(comment);
    _chapterComments[chapterId] = list;

    // Construir árbol y emitir
    final tree = _buildCommentTree(list);
    _chapterCommentControllers[chapterId]?.add(UnmodifiableListView(tree));
  }

  @override
  Future<void> replyToChapterComment({
    required String chapterId,
    required String parentCommentId,
    required CommentEntity reply,
  }) async {
    final list = _chapterComments[chapterId] ?? [];
    list.add(reply);
    _chapterComments[chapterId] = list;

    // Construir árbol y emitir
    final tree = _buildCommentTree(list);
    _chapterCommentControllers[chapterId]?.add(UnmodifiableListView(tree));
  }

  @override
  Stream<List<CommentEntity>> watchChapterComments(String chapterId,
      {String? userId}) {
    _chapterCommentControllers.putIfAbsent(
      chapterId,
      () => StreamController<List<CommentEntity>>.broadcast(),
    );
    final controller = _chapterCommentControllers[chapterId]!;
    final existing = _chapterComments[chapterId];
    if (existing != null) {
      final tree = _buildCommentTree(existing);
      controller.add(UnmodifiableListView(tree));
    }
    return controller.stream;
  }

  @override
  Future<void> toggleCommentLike({
    required String commentId,
    required String userId,
    required bool isLiked,
  }) async {
    // Implementación simple para testing
    // En producción usar Supabase
  }

  @override
  Future<void> toggleChapterCommentLike({
    required String commentId,
    required String userId,
    required bool isLiked,
  }) async {
    // Implementación simple para testing
    // En producción usar Supabase
  }

  @override
  Future<BookEntity> updateBook({
    required String bookId,
    String? title,
    String? description,
    String? category,
    String? coverPath,
    List<ChapterEntity>? chapters,
    int? publishedChapterIndex,
  }) async {
    final book = _books[bookId];
    if (book == null) {
      throw Exception('Book not found');
    }

    final updatedBook = book.copyWith(
      title: title ?? book.title,
      description: description ?? book.description,
      category: category ?? book.category,
      coverPath: coverPath ?? book.coverPath,
      chapters: chapters ?? book.chapters,
      publishedChapterIndex:
          publishedChapterIndex ?? book.publishedChapterIndex,
    );

    _books[bookId] = updatedBook;
    _emitBooks();
    _emitBook(updatedBook, null);
    return updatedBook;
  }

  @override
  Future<void> deleteBook({required String bookId}) async {
    _books.remove(bookId);
    _comments.remove(bookId);
    _viewsByBook.remove(bookId);
    _reactionsByBook.remove(bookId);
    _bookControllers[bookId]?.close();
    _bookControllers.remove(bookId);
    _commentControllers[bookId]?.close();
    _commentControllers.remove(bookId);
    _emitBooks();
  }
}
