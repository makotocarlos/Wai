import 'package:sqflite/sqflite.dart';
import 'package:wappa_app/core/database/offline_database.dart';
import 'package:wappa_app/core/sync/sync_manager.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/chapter_entity.dart';

class BooksLocalDataSource {
  final OfflineDatabase _localDb;
  final SyncManager _syncManager;

  BooksLocalDataSource({
    required OfflineDatabase localDb,
    required SyncManager syncManager,
  })  : _localDb = localDb,
        _syncManager = syncManager;

  // ==================== LECTURA ====================

  Future<List<BookEntity>> getCachedBooks({String? authorId}) async {
    final db = await _localDb.database;
    
    final List<Map<String, dynamic>> maps = authorId != null
        ? await db.query('books', where: 'author_id = ?', whereArgs: [authorId])
        : await db.query('books');

    // 🔥 Cargar cada libro con sus capítulos
    final books = <BookEntity>[];
    for (final map in maps) {
      final book = await _bookFromMapWithChapters(map);
      books.add(book);
    }
    
    return books;
  }

  Future<BookEntity?> getCachedBook(String bookId) async {
    final db = await _localDb.database;
    
    final maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    
    // 🔥 Cargar libro con sus capítulos
    return await _bookFromMapWithChapters(maps.first);
  }

  Future<List<BookEntity>> getCachedFavorites(String userId) async {
    final db = await _localDb.database;
    
    final maps = await db.rawQuery('''
      SELECT b.* FROM books b
      INNER JOIN favorites f ON b.id = f.book_id
      WHERE f.user_id = ?
      ORDER BY f.created_at DESC
    ''', [userId]);

    // 🔥 Cargar cada libro con sus capítulos
    final books = <BookEntity>[];
    for (final map in maps) {
      final book = await _bookFromMapWithChapters(map);
      books.add(book);
    }
    
    return books;
  }

  // ==================== ESCRITURA ====================

  Future<void> cacheBook(BookEntity book, {bool isSynced = true}) async {
    final db = await _localDb.database;
    
    // 🔥 Guardar libro
    await db.insert(
      'books',
      _bookToMap(book, isSynced: isSynced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // 🔥 Guardar capítulos del libro
    if (book.chapters.isNotEmpty) {
      for (final chapter in book.chapters) {
        await db.insert(
          'chapters',
          {
            'id': '${book.id}_chapter_${chapter.order}',
            'book_id': book.id,
            'title': chapter.title,
            'content': chapter.content,
            'chapter_order': chapter.order,
            'is_published': chapter.isPublished ? 1 : 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'is_synced': isSynced ? 1 : 0,
            'last_modified': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> cacheBooks(List<BookEntity> books, {bool isSynced = true}) async {
    final db = await _localDb.database;
    final batch = db.batch();

    for (final book in books) {
      // 🔥 Guardar libro
      batch.insert(
        'books',
        _bookToMap(book, isSynced: isSynced),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // 🔥 Guardar capítulos del libro
      if (book.chapters.isNotEmpty) {
        for (final chapter in book.chapters) {
          batch.insert(
            'chapters',
            {
              'id': '${book.id}_chapter_${chapter.order}',
              'book_id': book.id,
              'title': chapter.title,
              'content': chapter.content,
              'chapter_order': chapter.order,
              'is_published': chapter.isPublished ? 1 : 0,
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'is_synced': isSynced ? 1 : 0,
              'last_modified': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> updateCachedBook(String bookId, Map<String, dynamic> updates) async {
    final db = await _localDb.database;
    
    final currentBook = await getCachedBook(bookId);
    if (currentBook == null) return;

    await db.update(
      'books',
      {
        ...updates,
        'is_synced': 0,
        'last_modified': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );

    // Agregar a la cola de sincronización
    await _syncManager.addToSyncQueue(
      operationType: 'update',
      entityType: 'book',
      entityId: bookId,
      payload: updates,
    );
  }

  Future<void> deleteCachedBook(String bookId) async {
    final db = await _localDb.database;
    
    print('🗑️ Eliminando del caché local: $bookId');
    
    // 1. Eliminar capítulos primero
    final chaptersDeleted = await db.delete(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    print('✅ $chaptersDeleted capítulos eliminados del caché');
    
    // 2. Eliminar el libro
    final booksDeleted = await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    print('✅ $booksDeleted libro eliminado del caché');

    // 3. Agregar a la cola de sincronización
    await _syncManager.addToSyncQueue(
      operationType: 'delete',
      entityType: 'book',
      entityId: bookId,
      payload: {},
    );
    
    print('✅ Eliminación encolada para sincronización');
  }

  Future<void> addFavorite(String userId, String bookId) async {
    final db = await _localDb.database;
    
    await db.insert(
      'favorites',
      {
        'id': '${userId}_$bookId',
        'user_id': userId,
        'book_id': bookId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Agregar a la cola de sincronización
    await _syncManager.addToSyncQueue(
      operationType: 'create',
      entityType: 'favorite',
      entityId: bookId,
      payload: {'user_id': userId, 'book_id': bookId},
    );
  }

  Future<void> removeFavorite(String userId, String bookId) async {
    final db = await _localDb.database;
    
    await db.delete(
      'favorites',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );

    // Agregar a la cola de sincronización
    await _syncManager.addToSyncQueue(
      operationType: 'delete',
      entityType: 'favorite',
      entityId: bookId,
      payload: {'user_id': userId, 'book_id': bookId},
    );
  }

  Future<bool> isCached(String bookId) async {
    final db = await _localDb.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM books WHERE id = ?', [bookId]),
    );
    return (count ?? 0) > 0;
  }

  // ==================== MAPPERS ====================

  // 🔥 Cargar libro CON sus capítulos desde SQLite
  Future<BookEntity> _bookFromMapWithChapters(Map<String, dynamic> map) async {
    final db = await _localDb.database;
    final bookId = map['id'] as String;
    
    // Cargar capítulos del libro
    final chapterMaps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_order ASC',
    );
    
    final chapters = chapterMaps.map((chapterMap) => ChapterEntity(
      id: chapterMap['id'] as String,
      order: chapterMap['chapter_order'] as int,
      title: chapterMap['title'] as String,
      content: chapterMap['content'] as String,
      isPublished: (chapterMap['is_published'] as int) == 1,
    )).toList();
    
    return BookEntity(
      id: bookId,
      authorId: map['author_id'] as String,
      authorName: map['author_name'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      description: (map['description'] as String?) ?? '',
      coverPath: map['cover_path'] as String?,
      publishedChapterIndex: map['published_chapter_index'] as int,
      viewCount: map['views_count'] as int,
      likeCount: map['likes_count'] as int,
      dislikeCount: map['dislikes_count'] as int,
      favoritesCount: map['favorites_count'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      userReaction: _parseReaction(map['user_reaction'] as String?),
      isFavorited: (map['is_favorite'] as int) == 1,
      chapters: chapters, // 🔥 INCLUIR CAPÍTULOS
    );
  }

  BookReactionType? _parseReaction(String? reaction) {
    if (reaction == null) return null;
    return reaction == 'like' ? BookReactionType.like : BookReactionType.dislike;
  }

  Map<String, dynamic> _bookToMap(BookEntity book, {required bool isSynced}) {
    return {
      'id': book.id,
      'author_id': book.authorId,
      'author_name': book.authorName,
      'title': book.title,
      'category': book.category,
      'description': book.description,
      'cover_path': book.coverPath,
      'published_chapter_index': book.publishedChapterIndex,
      'views_count': book.viewCount,
      'likes_count': book.likeCount,
      'dislikes_count': book.dislikeCount,
      'favorites_count': book.favoritesCount,
      'comments_count': 0, // No está en la entidad, usar 0 por defecto
      'created_at': book.createdAt.millisecondsSinceEpoch,
      'user_reaction': book.userReaction?.toString().split('.').last,
      'is_favorite': book.isFavorited ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'last_modified': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
