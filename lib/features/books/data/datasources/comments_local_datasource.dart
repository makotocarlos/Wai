import 'package:sqflite/sqflite.dart';
import 'package:wappa_app/core/database/offline_database.dart';
import 'package:wappa_app/core/sync/sync_manager.dart';
import 'package:wappa_app/features/books/domain/entities/comment_entity.dart';

/// Datasource local para comentarios (SQLite)
class CommentsLocalDataSource {
  final OfflineDatabase _localDb;
  final SyncManager _syncManager;

  CommentsLocalDataSource({
    required OfflineDatabase localDb,
    required SyncManager syncManager,
  })  : _localDb = localDb,
        _syncManager = syncManager;

  // 🔥 OBTENER comentarios desde caché
  Future<List<CommentEntity>> getCachedComments({
    String? bookId,
    String? chapterId,
  }) async {
    final db = await _localDb.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (bookId != null) {
      whereClause += ' AND book_id = ?';
      whereArgs.add(bookId);
    }
    
    if (chapterId != null) {
      whereClause += ' AND chapter_id = ?';
      whereArgs.add(chapterId);
    }
    
    final maps = await db.query(
      'comments',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _mapToCommentEntity(map)).toList();
  }

  // 🔥 GUARDAR comentarios en caché
  Future<void> cacheComments(
    List<CommentEntity> comments, {
    bool isSynced = false,
  }) async {
    final db = await _localDb.database;
    
    for (final comment in comments) {
      await db.insert(
        'comments',
        {
          'id': comment.id,
          'book_id': '', // Se necesitará pasar como parámetro
          'chapter_id': null,
          'user_id': comment.userId,
          'username': comment.userName,
          'avatar_url': comment.userAvatarUrl,
          'content': comment.content,
          'parent_id': comment.parentCommentId,
          'likes_count': comment.likeCount,
          'replies_count': comment.replyCount,
          'created_at': comment.createdAt.millisecondsSinceEpoch,
          'is_synced': isSynced ? 1 : 0,
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // 🔥 CREAR comentario localmente
  Future<void> createCommentLocally({
    required CommentEntity comment,
    required String bookId,
    String? chapterId,
  }) async {
    final db = await _localDb.database;
    
    await db.insert(
      'comments',
      {
        'id': comment.id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'user_id': comment.userId,
        'username': comment.userName,
        'avatar_url': comment.userAvatarUrl,
        'content': comment.content,
        'parent_id': comment.parentCommentId,
        'likes_count': comment.likeCount,
        'replies_count': comment.replyCount,
        'created_at': comment.createdAt.millisecondsSinceEpoch,
        'is_synced': 0,
        'last_modified': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Encolar para sincronizar
    await _syncManager.addToSyncQueue(
      operationType: 'create',
      entityType: 'comment',
      entityId: comment.id,
      payload: {
        'book_id': bookId,
        'chapter_id': chapterId,
        'user_id': comment.userId,
        'content': comment.content,
        'parent_id': comment.parentCommentId,
      },
    );
  }

  // 🔥 ELIMINAR comentario del caché
  Future<void> deleteCommentLocally(String commentId) async {
    final db = await _localDb.database;
    
    await db.delete(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
    );

    // Encolar para sincronizar
    await _syncManager.addToSyncQueue(
      operationType: 'delete',
      entityType: 'comment',
      entityId: commentId,
      payload: {},
    );
  }

  // 🔥 DAR LIKE a comentario localmente
  Future<void> likeCommentLocally({
    required String commentId,
    required String userId,
  }) async {
    final db = await _localDb.database;
    
    final likeId = '${userId}_$commentId';
    
    await db.insert(
      'comment_likes',
      {
        'id': likeId,
        'comment_id': commentId,
        'user_id': userId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Incrementar contador de likes en el comentario
    await db.rawUpdate(
      'UPDATE comments SET likes_count = likes_count + 1 WHERE id = ?',
      [commentId],
    );

    // Encolar para sincronizar
    await _syncManager.addToSyncQueue(
      operationType: 'create',
      entityType: 'comment_like',
      entityId: likeId,
      payload: {
        'comment_id': commentId,
        'user_id': userId,
      },
    );
  }

  // 🔥 QUITAR LIKE de comentario localmente
  Future<void> unlikeCommentLocally({
    required String commentId,
    required String userId,
  }) async {
    final db = await _localDb.database;
    
    final likeId = '${userId}_$commentId';
    
    await db.delete(
      'comment_likes',
      where: 'id = ?',
      whereArgs: [likeId],
    );

    // Decrementar contador de likes en el comentario
    await db.rawUpdate(
      'UPDATE comments SET likes_count = likes_count - 1 WHERE id = ?',
      [commentId],
    );

    // Encolar para sincronizar
    await _syncManager.addToSyncQueue(
      operationType: 'delete',
      entityType: 'comment_like',
      entityId: likeId,
      payload: {
        'comment_id': commentId,
        'user_id': userId,
      },
    );
  }

  // 🔥 Mapear desde SQLite a CommentEntity
  CommentEntity _mapToCommentEntity(Map<String, dynamic> map) {
    return CommentEntity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['username'] as String,
      userAvatarUrl: map['avatar_url'] as String?,
      content: map['content'] as String,
      parentCommentId: map['parent_id'] as String?,
      likeCount: map['likes_count'] as int? ?? 0,
      replyCount: map['replies_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      userHasLiked: false, // Se calculará después con otra query
      replies: const [], // Se cargarán después si es necesario
    );
  }
}
