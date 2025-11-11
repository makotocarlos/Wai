import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wappa_app/core/sync/sync_manager.dart';
import 'package:wappa_app/features/books/data/datasources/books_local_datasource.dart';
import 'package:wappa_app/core/di/injection.dart';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_search_sort.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';

class SupabaseBooksRepository implements BooksRepository {
  SupabaseBooksRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  static const String _booksTable = 'books';
  static const String _chaptersTable = 'book_chapters';
  static const String _commentsTable = 'book_comments';
  static const String _viewsTable = 'book_views';
  static const String _reactionsTable = 'book_reactions';
  static const String _favoritesTable = 'favorites';
  static const String _coversBucket = 'book-covers';

  static final Uuid _uuid = const Uuid();

  @override
  Stream<List<BookEntity>> watchBooks({String? userId}) async* {
    final syncManager = sl<SyncManager>();
    final localDataSource = sl<BooksLocalDataSource>();
    
    // 🔥 Si estamos OFFLINE, usar solo caché
    if (!syncManager.isOnline) {
      print('📴 Offline - modo caché local');
      
      // Emitir caché inmediatamente
      try {
        final cachedBooks = await localDataSource.getCachedBooks(authorId: userId);
        print('📚 Libros en caché (offline): ${cachedBooks.length}');
        yield cachedBooks;
      } catch (e) {
        print('⚠️ Error cargando caché: $e');
      }
      
      // Crear un stream que emita cada segundo para detectar cambios
      // TODO: Mejorar con StreamController que se notifique en cada cambio
      await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
        try {
          final cachedBooks = await localDataSource.getCachedBooks(authorId: userId);
          yield cachedBooks;
        } catch (e) {
          print('⚠️ Error actualizando caché: $e');
        }
      }
      return;
    }
    
    // 🔥 Si estamos ONLINE, stream desde Supabase (sin emitir caché primero)
    try {
      // 🚀 PRIMERO: Sincronizar libros locales pendientes
      await _syncLocalBooks(userId);
      
      final baseQuery = _client.from(_booksTable);
      final streamBuilder = baseQuery.stream(primaryKey: ['id']);

      final stream = userId != null
          ? streamBuilder
              .eq('author_id', userId)
              .order('created_at', ascending: false)
          : streamBuilder.order('created_at', ascending: false);

      await for (final rows in stream) {
        final books = await Future.wait(
          rows.map(
            (row) => _mapRowToBook(
              row,
              loadChapters: true,
            ),
          ),
        );
        
        // 🔥 GUARDAR en caché para la próxima vez
        try {
          await localDataSource.cacheBooks(books, isSynced: true);
        } catch (e) {
          print('⚠️ Error guardando en caché: $e');
        }
        
        yield books;
      }
    } catch (error) {
      print('❌ Error cargando desde Supabase: $error');
      
      // 🔥 Si falla Supabase, intentar caché como fallback
      try {
        final cachedBooks = await localDataSource.getCachedBooks(authorId: userId);
        if (cachedBooks.isNotEmpty) {
          print('📚 Usando caché como fallback: ${cachedBooks.length}');
          yield cachedBooks;
          return;
        }
      } catch (e) {
        print('⚠️ Error en fallback de caché: $e');
      }
      
      // Solo lanzar error si NO hay caché
      throw Exception('No se pudieron cargar los libros');
    }
  }

  @override
  Stream<BookEntity> watchBook({
    required String bookId,
    required String userId,
  }) async* {
    final syncManager = sl<SyncManager>();
    final localDataSource = sl<BooksLocalDataSource>();
    
    // 🔥 PRIMERO: Intentar cargar desde caché (respuesta inmediata)
    try {
      final cachedBooks = await localDataSource.getCachedBooks();
      final cachedBook = cachedBooks.where((b) => b.id == bookId).firstOrNull;
      if (cachedBook != null) {
        print('✅ Libro cargado desde caché: ${cachedBook.title}');
        yield cachedBook;
      }
    } catch (e) {
      print('⚠️ Error cargando libro desde caché: $e');
    }
    
    // 🔥 Si estamos offline, devolver solo el caché
    if (!syncManager.isOnline) {
      print('📴 Offline - usando solo caché local para libro $bookId');
      return;
    }
    
    // 🔥 Si estamos online, intentar cargar desde Supabase
    try {
      final stream = _client
          .from(_booksTable)
          .stream(primaryKey: ['id'])
          .eq('id', bookId)
          .limit(1);

      await for (final rows in stream) {
        if (rows.isEmpty) {
          throw Exception('El libro ya no esta disponible.');
        }
        
        final row = rows.first;
        final book = await _mapRowToBook(
          row,
          currentUserId: userId,
          loadChapters: true,
        );
        
        // 🔥 GUARDAR en caché para la próxima vez
        try {
          await localDataSource.cacheBooks([book], isSynced: true);
        } catch (e) {
          print('⚠️ Error guardando libro en caché: $e');
        }
        
        yield book;
      }
    } catch (error) {
      print('❌ Error cargando libro desde Supabase: $error');
      
      // 🔥 Si falla Supabase, intentar caché como fallback
      try {
        final cachedBooks = await localDataSource.getCachedBooks();
        final cachedBook = cachedBooks.where((b) => b.id == bookId).firstOrNull;
        if (cachedBook != null) {
          yield cachedBook;
          return;
        }
      } catch (e) {
        print('❌ Error cargando fallback de caché: $e');
      }
      
      // Solo lanzar error si no hay datos en caché
      throw Exception('No se pudo cargar el libro');
    }
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
    final syncManager = sl<SyncManager>();
    final localDataSource = sl<BooksLocalDataSource>();
    
    // Generar ID único para el libro
    final bookId = 'local_${DateTime.now().millisecondsSinceEpoch}_${authorId.substring(0, 8)}';
    
    // Crear entidad del libro localmente
    final newBook = BookEntity(
      id: bookId,
      authorId: authorId,
      authorName: authorName,
      title: title,
      category: category,
      description: description,
      coverPath: coverPath,
      publishedChapterIndex: publishedChapterIndex,
      chapters: chapters,
      viewCount: 0,
      likeCount: 0,
      dislikeCount: 0,
      favoritesCount: 0,
      createdAt: DateTime.now(),
      userReaction: null,
      isFavorited: false,
    );
    
    // 🔥 GUARDAR en caché local PRIMERO (siempre funciona)
    try {
      await localDataSource.cacheBooks([newBook], isSynced: false);
      print('✅ Libro guardado localmente: $title');
    } catch (e) {
      print('❌ Error guardando en caché local: $e');
      throw Exception('No se pudo guardar el libro localmente: $e');
    }
    
    // 🔥 Si estamos ONLINE, crear en Supabase inmediatamente
    if (syncManager.isOnline) {
      try {
        final inserted = await _client
            .from(_booksTable)
            .insert({
              'author_id': authorId,
              'author_name': authorName,
              'title': title,
              'category': category,
              'description': description,
              'cover_path': coverPath,
              'published_chapter_index': publishedChapterIndex,
            })
            .select()
            .maybeSingle();

        if (inserted == null) {
          throw Exception('No se pudo crear el libro en Supabase.');
        }

        final supabaseBookId = inserted['id'] as String;

        // Insertar capítulos en Supabase
        if (chapters.isNotEmpty) {
          final payload = chapters
              .map(
                (chapter) => {
                  'book_id': supabaseBookId,
                  'chapter_order': chapter.order,
                  'title': chapter.title,
                  'content': chapter.content,
                  'is_published': chapter.isPublished,
                },
              )
              .toList();

          await _client.from(_chaptersTable).insert(payload);
        }

        // Actualizar libro con ID real de Supabase
        final supabaseBook = await _mapRowToBook(
          inserted,
          currentUserId: authorId,
          loadChapters: true,
        );
        
        // Actualizar caché con el libro sincronizado
        await localDataSource.cacheBooks([supabaseBook], isSynced: true);
        print('✅ Libro sincronizado con Supabase: $title');
        
        return supabaseBook;
      } catch (e) {
        print('⚠️ Error creando en Supabase (libro guardado localmente): $e');
        // Encolar para sincronizar después
        await syncManager.addToSyncQueue(
          operationType: 'create',
          entityType: 'book',
          entityId: bookId,
          payload: {
            'author_id': authorId,
            'author_name': authorName,
            'title': title,
            'category': category,
            'description': description,
            'cover_path': coverPath,
            'published_chapter_index': publishedChapterIndex,
            'chapters': chapters.map((c) => {
              'order': c.order,
              'title': c.title,
              'content': c.content,
              'is_published': c.isPublished,
            }).toList(),
          },
        );
        // Devolver libro local (usuario lo ve inmediatamente)
        return newBook;
      }
    } else {
      // 🔥 OFFLINE: Encolar para sincronizar cuando vuelva conexión
      print('📴 Offline - libro se sincronizará cuando vuelva WiFi');
      await syncManager.addToSyncQueue(
        operationType: 'create',
        entityType: 'book',
        entityId: bookId,
        payload: {
          'author_id': authorId,
          'author_name': authorName,
          'title': title,
          'category': category,
          'description': description,
          'cover_path': coverPath,
          'published_chapter_index': publishedChapterIndex,
          'chapters': chapters.map((c) => {
            'order': c.order,
            'title': c.title,
            'content': c.content,
            'is_published': c.isPublished,
          }).toList(),
        },
      );
      
      return newBook;
    }
  }

  @override
  Future<void> addView({
    required String bookId,
    required String userId,
  }) async {
    final existing = await _client
        .from(_viewsTable)
        .select()
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    await _client.from(_viewsTable).insert({
      'book_id': bookId,
      'user_id': userId,
    });
  }

  @override
  Future<void> reactToBook({
    required String bookId,
    required String userId,
    required BookReactionType? reaction,
  }) async {
    final previous = await _client
        .from(_reactionsTable)
        .select('reaction')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    final BookReactionType? previousReaction = previous == null
        ? null
        : _reactionFromString(previous['reaction'] as String?);

    if (reaction == null) {
      if (previousReaction != null) {
        await _client
            .from(_reactionsTable)
            .delete()
            .eq('book_id', bookId)
            .eq('user_id', userId);
      }
      return;
    }

    final payload = {
      'book_id': bookId,
      'user_id': userId,
      'reaction': _reactionToString(reaction),
    };

    if (previousReaction == null) {
      await _client.from(_reactionsTable).insert(payload);
      return;
    }

    if (previousReaction == reaction) {
      return;
    }

    await _client
        .from(_reactionsTable)
        .update({'reaction': _reactionToString(reaction)})
        .eq('book_id', bookId)
        .eq('user_id', userId);
  }

  @override
  Future<void> toggleFavorite({
    required String bookId,
    required String userId,
  }) async {
    final existing = await _client
        .from(_favoritesTable)
        .select('id')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _client.from(_favoritesTable).insert({
        'book_id': bookId,
        'user_id': userId,
      });
      return;
    }

    await _client
        .from(_favoritesTable)
        .delete()
        .eq('book_id', bookId)
        .eq('user_id', userId);
  }

  @override
  Future<String> uploadBookCover({
    required String authorId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final storage = _client.storage.from(_coversBucket);
    final sanitized = fileExtension.replaceAll('.', '').toLowerCase();
    final extension = sanitized.isEmpty ? 'jpg' : sanitized;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$extension';
    final path = '$authorId/$fileName';

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: _contentTypeForExtension(extension),
      ),
    );

    return storage.getPublicUrl(path);
  }

  @override
  Stream<List<BookEntity>> watchFavoriteBooks({
    required String userId,
  }) {
    final favoritesStream = _client
        .from(_favoritesTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return favoritesStream.asyncMap((rows) async {
      if (rows.isEmpty) {
        return <BookEntity>[];
      }

      final favoriteRows =
          rows.where((row) => row['book_id'] != null).toList(growable: false);

      if (favoriteRows.isEmpty) {
        return <BookEntity>[];
      }

      final bookIds = favoriteRows
          .map((row) => row['book_id'] as String)
          .toList(growable: false);

      final booksResponse =
          await _client.from(_booksTable).select('*').inFilter('id', bookIds);

      final books = await Future.wait(
        booksResponse.map(
          (row) => _mapRowToBook(
            row,
            currentUserId: userId,
            loadChapters: false,
          ),
        ),
      );

      final order = <String, int>{};
      for (var index = 0; index < bookIds.length; index++) {
        order.putIfAbsent(bookIds[index], () => index);
      }

      books.sort(
        (a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0),
      );

      return books;
    });
  }

  @override
  Future<void> addComment({
    required String bookId,
    required CommentEntity comment,
  }) async {
    await _client.from(_commentsTable).insert({
      'id': comment.id,
      'book_id': bookId,
      'user_id': comment.userId,
      'username': comment.userName,
      'user_avatar_url': comment.userAvatarUrl,
      'content': comment.content,
      'created_at': comment.createdAt.toIso8601String(),
      // parent_comment_id es NULL para comentarios raíz
    });
  }

  @override
  Future<void> replyToComment({
    required String bookId,
    required String parentCommentId,
    required CommentEntity reply,
  }) async {
    await _client.from(_commentsTable).insert({
      'id': reply.id,
      'book_id': bookId,
      'user_id': reply.userId,
      'username': reply.userName,
      'user_avatar_url': reply.userAvatarUrl,
      'content': reply.content,
      'created_at': reply.createdAt.toIso8601String(),
      'parent_comment_id': parentCommentId, // FK al comentario padre
    });
  }

  @override
  Future<List<BookEntity>> searchBooks({
    String? query,
    String? category,
    BookSearchSort sortBy = BookSearchSort.recent,
    int limit = 40,
    String? currentUserId,
  }) async {
    final sanitizedLimit = limit <= 0 ? 20 : limit;
    final fetchLimit = sortBy == BookSearchSort.recent
        ? sanitizedLimit
        : (sanitizedLimit * 3).clamp(sanitizedLimit, 200).toInt();

    try {
      var request = _client.from(_booksTable).select();

      final normalizedCategory = category?.trim();
      if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
        final categoryPattern = _escapeIlikePattern(normalizedCategory);
        request = request.ilike('category', categoryPattern);
      }

      final sanitizedQuery = query?.trim();
      if (sanitizedQuery != null && sanitizedQuery.isNotEmpty) {
        final escaped = _escapeIlikePattern(sanitizedQuery);
        final pattern = '%$escaped%';
        request = request.or(
          'title.ilike.$pattern,author_name.ilike.$pattern,category.ilike.$pattern',
        );
      }

      final rows =
          await request.order('created_at', ascending: false).limit(fetchLimit);

      final books = await Future.wait(
        rows.map(
          (row) => _mapRowToBook(
            row,
            currentUserId: currentUserId,
            loadChapters: false,
          ),
        ),
      );

      final sorted = List<BookEntity>.from(books);

      switch (sortBy) {
        case BookSearchSort.recent:
          sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case BookSearchSort.mostViewed:
          sorted.sort((a, b) => b.viewCount.compareTo(a.viewCount));
          break;
        case BookSearchSort.mostLiked:
          sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
          break;
      }

      if (sorted.length > sanitizedLimit) {
        return sorted.take(sanitizedLimit).toList(growable: false);
      }

      return sorted;
    } catch (e) {
      throw Exception('Error searching books: $e');
    }
  }

  @override
  Future<List<String>> fetchCategories() async {
    try {
      final rows = await _client
          .from(_booksTable)
          .select('category')
          .not('category', 'is', null);

      if (rows.isEmpty) {
        return <String>[];
      }

      final Map<String, String> normalized = {};

      for (final dynamic row in rows) {
        final data = row as Map<String, dynamic>;
        final raw = (data['category'] as String?)?.trim();
        if (raw == null || raw.isEmpty) {
          continue;
        }
        final key = raw.toLowerCase();
        normalized.putIfAbsent(key, () => raw);
      }

      final keys = normalized.keys.toList()..sort();
      return keys.map((key) => normalized[key]!).toList(growable: false);
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  @override
  Stream<List<CommentEntity>> watchComments(String bookId, {String? userId}) {
    final stream = _client
        .from(_commentsTable)
        .stream(primaryKey: ['id'])
        .eq('book_id', bookId)
        .order('created_at');

    return stream.asyncMap((rows) async {
      // Construir estructura jerárquica para comentarios de LIBRO
      return await _buildBookCommentTree(rows, userId: userId);
    });
  }

  @override
  Stream<List<CommentEntity>> watchChapterComments(String chapterId,
      {String? userId}) {
    final stream = _client
        .from('chapter_comments')
        .stream(primaryKey: ['id'])
        .eq('chapter_id', chapterId)
        .order('created_at');

    return stream.asyncMap((rows) async {
      // Construir estructura jerárquica para comentarios de CAPÍTULO
      return await _buildChapterCommentTree(rows, userId: userId);
    });
  }

  /// Construye árbol de comentarios de LIBRO (root + replies anidadas)
  Future<List<CommentEntity>> _buildBookCommentTree(
      List<Map<String, dynamic>> rows,
      {String? userId}) async {
    // 1. Obtener todos los IDs de comentarios
    final commentIds = rows.map((r) => r['id'] as String).toList();

    // 2. Cargar likes del usuario para todos los comentarios de una vez
    final Set<String> likedCommentIds = {};
    if (userId != null && commentIds.isNotEmpty) {
      try {
        final likes = await _client
            .from('book_comment_likes')
            .select('comment_id')
            .eq('user_id', userId)
            .inFilter('comment_id', commentIds);

        likedCommentIds
            .addAll(likes.map((like) => like['comment_id'] as String));
      } catch (e) {
        // Si hay error, continuar sin likes
      }
    }

    // 3. Mapear todos los comentarios
    final allComments = <String, CommentEntity>{};
    for (final row in rows) {
      final comment =
          _mapComment(row, likedByUser: likedCommentIds.contains(row['id']));
      allComments[comment.id] = comment;
    }

    // 4. Construir árbol: asignar replies a sus padres
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

          allComments[parentId] = parent.copyWith(replies: updatedReplies);
        }
      }
    }

    // 5. Retornar solo comentarios raíz (ya contienen sus replies)
    return rootComments
        .map((root) => allComments[root.id]!) // Obtener versión actualizada
        .toList();
  }

  Future<BookEntity> _mapRowToBook(
    Map<String, dynamic> row, {
    String? currentUserId,
    bool loadChapters = false,
  }) async {
    final String bookId = row['id'] as String;
    List<ChapterEntity> chapters = const [];

    if (loadChapters) {
      chapters = await _fetchChapters(bookId);
    }

    final metrics = await _fetchMetrics(bookId);
    final BookReactionType? userReaction = currentUserId == null
        ? null
        : await _fetchUserReaction(bookId, currentUserId);
    final bool isFavorited = currentUserId == null
        ? false
        : await _isBookFavorited(bookId, currentUserId);

    return BookEntity(
      id: bookId,
      authorId: row['author_id'] as String,
      authorName: (row['author_name'] as String?) ?? '',
      title: row['title'] as String,
      category: (row['category'] as String?) ?? 'General',
      description: (row['description'] as String?) ?? '',
      createdAt: _parseDateTime(row['created_at']),
      coverPath: row['cover_path'] as String?,
      chapters: chapters,
      publishedChapterIndex: _toInt(row['published_chapter_index']),
      viewCount: metrics.viewCount,
      likeCount: metrics.likeCount,
      dislikeCount: metrics.dislikeCount,
      userReaction: userReaction,
      favoritesCount: metrics.favoriteCount,
      isFavorited: isFavorited,
    );
  }

  String _escapeIlikePattern(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  Future<List<ChapterEntity>> _fetchChapters(String bookId) async {
    final response = await _client
        .from(_chaptersTable)
        .select()
        .eq('book_id', bookId)
        .order('chapter_order', ascending: true);

    return response.map<ChapterEntity>((dynamic row) {
      final data = row as Map<String, dynamic>;
      // Manejar el caso donde is_published no existe aún (durante migración)
      final isPublished = data.containsKey('is_published')
          ? (data['is_published'] as bool?) ?? true
          : true; // Por defecto true si no existe la columna

      return ChapterEntity(
        id: data['id'] as String,
        order: _toInt(data['chapter_order']),
        title: (data['title'] as String?) ?? 'Capitulo',
        content: (data['content'] as String?) ?? '',
        isPublished: isPublished,
      );
    }).toList();
  }

  Future<_BookMetrics> _fetchMetrics(String bookId) async {
    final views =
        await _client.from(_viewsTable).select('user_id').eq('book_id', bookId);

    final reactions = await _client
        .from(_reactionsTable)
        .select('reaction')
        .eq('book_id', bookId);

    final favorites = await _client
        .from(_favoritesTable)
        .select('user_id')
        .eq('book_id', bookId);

    int likes = 0;
    int dislikes = 0;
    for (final reaction in reactions) {
      final value = reaction['reaction'] as String?;
      if (value == 'like') {
        likes++;
      } else if (value == 'dislike') {
        dislikes++;
      }
    }

    return _BookMetrics(
      viewCount: views.length,
      likeCount: likes,
      dislikeCount: dislikes,
      favoriteCount: favorites.length,
    );
  }

  Future<BookReactionType?> _fetchUserReaction(
    String bookId,
    String userId,
  ) async {
    final result = await _client
        .from(_reactionsTable)
        .select('reaction')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) {
      return null;
    }
    return _reactionFromString(result['reaction'] as String?);
  }

  Future<bool> _isBookFavorited(String bookId, String userId) async {
    final result = await _client
        .from(_favoritesTable)
        .select('id')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    return result != null;
  }

  String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  CommentEntity _mapComment(Map<String, dynamic> row,
      {bool likedByUser = false}) {
    return CommentEntity(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userName: (row['username'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      createdAt: _parseDateTime(row['created_at']),
      userAvatarUrl: row['user_avatar_url'] as String?,
      parentCommentId: row['parent_comment_id'] as String?,
      replyCount: _toInt(row['reply_count']),
      likeCount: _toInt(row['like_count']),
      userHasLiked: likedByUser,
      // replies se construyen en _buildCommentTree
    );
  }

  BookReactionType? _reactionFromString(String? value) {
    switch (value) {
      case 'like':
        return BookReactionType.like;
      case 'dislike':
        return BookReactionType.dislike;
      default:
        return null;
    }
  }

  String _reactionToString(BookReactionType reaction) {
    switch (reaction) {
      case BookReactionType.like:
        return 'like';
      case BookReactionType.dislike:
        return 'dislike';
    }
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  // ===== Métodos de Comentarios de Capítulos =====

  @override
  Future<void> addChapterComment({
    required String chapterId,
    required CommentEntity comment,
  }) async {
    await _client.from('chapter_comments').insert({
      'id': comment.id,
      'chapter_id': chapterId,
      'user_id': comment.userId,
      'username': comment.userName,
      'user_avatar_url': comment.userAvatarUrl,
      'content': comment.content,
      'created_at': comment.createdAt.toIso8601String(),
      // parent_comment_id es NULL para comentarios raíz
    });
  }

  @override
  Future<void> replyToChapterComment({
    required String chapterId,
    required String parentCommentId,
    required CommentEntity reply,
  }) async {
    await _client.from('chapter_comments').insert({
      'id': reply.id,
      'chapter_id': chapterId,
      'user_id': reply.userId,
      'username': reply.userName,
      'user_avatar_url': reply.userAvatarUrl,
      'content': reply.content,
      'created_at': reply.createdAt.toIso8601String(),
      'parent_comment_id': parentCommentId,
    });
  }

  /// Construye árbol de comentarios de CAPÍTULO (root + replies anidadas)
  Future<List<CommentEntity>> _buildChapterCommentTree(
      List<Map<String, dynamic>> rows,
      {String? userId}) async {
    // 1. Obtener todos los IDs de comentarios
    final commentIds = rows.map((r) => r['id'] as String).toList();

    // 2. Cargar likes del usuario para todos los comentarios de una vez
    final Set<String> likedCommentIds = {};
    if (userId != null && commentIds.isNotEmpty) {
      try {
        final likes = await _client
            .from('chapter_comment_likes')
            .select('comment_id')
            .eq('user_id', userId)
            .inFilter('comment_id', commentIds);

        likedCommentIds
            .addAll(likes.map((like) => like['comment_id'] as String));
      } catch (e) {
        // Si hay error, continuar sin likes
      }
    }

    // 3. Mapear todos los comentarios
    final allComments = <String, CommentEntity>{};
    for (final row in rows) {
      final comment =
          _mapComment(row, likedByUser: likedCommentIds.contains(row['id']));
      allComments[comment.id] = comment;
    }

    // 4. Construir árbol: asignar replies a sus padres
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

          allComments[parentId] = parent.copyWith(replies: updatedReplies);
        }
      }
    }

    // 5. Retornar solo comentarios raíz (ya contienen sus replies)
    return rootComments
        .map((root) => allComments[root.id]!) // Obtener versión actualizada
        .toList();
  }

  // ===== Métodos de Likes en Comentarios =====

  @override
  Future<void> toggleCommentLike({
    required String commentId,
    required String userId,
    required bool isLiked,
  }) async {
    if (isLiked) {
      // Quitar like
      await _client
          .from('book_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } else {
      // Dar like
      await _client.from('book_comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
    }
  }

  @override
  Future<void> toggleChapterCommentLike({
    required String commentId,
    required String userId,
    required bool isLiked,
  }) async {
    if (isLiked) {
      // Quitar like
      await _client
          .from('chapter_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } else {
      // Dar like
      await _client.from('chapter_comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
    }
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
    try {
      // Actualizar datos del libro
      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (category != null) updateData['category'] = category;
      if (coverPath != null) updateData['cover_path'] = coverPath;
      if (publishedChapterIndex != null) {
        updateData['published_chapter_index'] = publishedChapterIndex;
      } else if (chapters != null) {
        updateData['published_chapter_index'] =
            _computePublishedChapterIndex(chapters);
      }

      Map<String, dynamic>? updated;
      if (updateData.isNotEmpty) {
        updated = await _client
            .from(_booksTable)
            .update(updateData)
            .eq('id', bookId)
            .select()
            .maybeSingle();

        if (updated == null) {
          throw Exception('No se pudo actualizar el libro.');
        }
      } else {
        // Si no hubo cambios directos en el libro, obtener los datos actuales
        updated = await _client
            .from(_booksTable)
            .select()
            .eq('id', bookId)
            .maybeSingle();

        if (updated == null) {
          throw Exception('No se pudo obtener el libro.');
        }
      }

      // Actualizar capítulos si se proporcionaron
      if (chapters != null && chapters.isNotEmpty) {
        // Obtener capítulos existentes para no duplicar
        final existingChapters = await _client
            .from(_chaptersTable)
            .select('id, chapter_order')
            .eq('book_id', bookId);

        final orderToId = <int, String>{};
        for (final ch in existingChapters) {
          final chapterId = ch['id'] as String?;
          final rawOrder = ch['chapter_order'];
          if (chapterId == null || rawOrder == null) {
            continue;
          }

          final order = _toInt(rawOrder);
          orderToId[order] = chapterId;
        }

        final existingOrders = orderToId.keys.toSet();

        // Solo insertar capítulos NUEVOS (que no existen)
        final newChapters = chapters
            .where((chapter) => !existingOrders.contains(chapter.order))
            .toList();

        if (newChapters.isNotEmpty) {
          final payload = newChapters
              .map(
                (chapter) => {
                  'book_id': bookId,
                  'chapter_order': chapter.order,
                  'title': chapter.title,
                  'content': chapter.content,
                  'is_published': chapter.isPublished,
                },
              )
              .toList();

          await _client.from(_chaptersTable).insert(payload);
        }

        // Actualizar capítulos existentes (contenido Y estado de publicación)
        for (final chapter in chapters) {
          final chapterId = orderToId[chapter.order];
          if (chapterId != null) {
            await _client.from(_chaptersTable).update({
              'title': chapter.title,
              'content': chapter.content,
              'is_published': chapter.isPublished, // Actualizar estado
            }).eq('id', chapterId);
          }
        }
      }

      // Obtener el libro actualizado con todos los datos
      final bookData = await _client
          .from(_booksTable)
          .select()
          .eq('id', bookId)
          .maybeSingle();

      if (bookData == null) {
        throw Exception('No se pudo obtener el libro actualizado.');
      }

      final updatedBook = await _mapRowToBook(
        bookData,
        loadChapters: true,
      );
      
      // 🔥 ACTUALIZAR caché local con el libro modificado
      try {
        final localDataSource = sl<BooksLocalDataSource>();
        await localDataSource.cacheBooks([updatedBook], isSynced: true);
        print('✅ Libro actualizado en caché local: ${updatedBook.title}');
      } catch (e) {
        print('⚠️ Error actualizando caché local: $e');
      }
      
      return updatedBook;
    } catch (e) {
      throw Exception('Error al actualizar libro: $e');
    }
  }

  int _computePublishedChapterIndex(List<ChapterEntity> chapters) {
    int highestOrderIndex = -1;
    for (final chapter in chapters) {
      if (!chapter.isPublished) {
        continue;
      }

      final orderIndex = chapter.order > 0 ? chapter.order - 1 : chapter.order;
      if (orderIndex > highestOrderIndex) {
        highestOrderIndex = orderIndex;
      }
    }

    return highestOrderIndex;
  }

  @override
  Future<void> deleteBook({required String bookId}) async {
    final syncManager = sl<SyncManager>();
    final localDataSource = sl<BooksLocalDataSource>();
    
    print('🗑️ Intentando eliminar libro: $bookId');
    
    try {
      // 🔥 PRIMERO: Eliminar del caché local (respuesta inmediata)
      await localDataSource.deleteCachedBook(bookId);
      print('✅ Libro eliminado del caché local: $bookId');
      
      // 🔥 Si estamos online, eliminar de Supabase inmediatamente
      if (syncManager.isOnline) {
        try {
          print('🌐 Online - eliminando de Supabase...');
          print('📋 Libro ID: $bookId');
          
          // 1. Eliminar capítulos primero (por si no hay CASCADE)
          print('⏳ Eliminando capítulos...');
          final chaptersResult = await _client
              .from(_chaptersTable)
              .delete()
              .eq('book_id', bookId)
              .select();
          print('✅ ${chaptersResult.length} capítulos eliminados de Supabase');
          print('   Capítulos eliminados: $chaptersResult');
          
          // 2. Eliminar comentarios de los capítulos del libro
          // Los comentarios están vinculados a chapter_id, no a book_id
          print('⏳ Eliminando comentarios de los capítulos...');
          int totalComments = 0;
          for (final chapter in chaptersResult) {
            final chapterId = chapter['id'] as String;
            final commentsResult = await _client
                .from('chapter_comments')
                .delete()
                .eq('chapter_id', chapterId)
                .select();
            totalComments += commentsResult.length;
          }
          print('✅ $totalComments comentarios eliminados de Supabase');
          
          // 3. Eliminar reacciones del libro
          print('⏳ Eliminando reacciones...');
          final reactionsResult = await _client
              .from(_reactionsTable)
              .delete()
              .eq('book_id', bookId)
              .select();
          print('✅ ${reactionsResult.length} reacciones eliminadas de Supabase');
          
          // 4. Eliminar vistas del libro
          print('⏳ Eliminando vistas...');
          final viewsResult = await _client
              .from(_viewsTable)
              .delete()
              .eq('book_id', bookId)
              .select();
          print('✅ ${viewsResult.length} vistas eliminadas de Supabase');
          
          // 5. Eliminar favoritos del libro
          print('⏳ Eliminando favoritos...');
          final favoritesResult = await _client
              .from('favorites')  // ✅ Nombre correcto de la tabla
              .delete()
              .eq('book_id', bookId)
              .select();
          print('✅ ${favoritesResult.length} favoritos eliminados de Supabase');
          
          // 6. Finalmente eliminar el libro
          print('⏳ Eliminando libro...');
          final bookResult = await _client
              .from(_booksTable)
              .delete()
              .eq('id', bookId)
              .select();
          
          print('✅ Libro eliminado de Supabase: $bookResult');
          print('🎉 ELIMINACIÓN COMPLETA - Total eliminado:');
          print('   - Libro: 1');
          print('   - Capítulos: ${chaptersResult.length}');
          print('   - Comentarios: $totalComments');
          print('   - Reacciones: ${reactionsResult.length}');
          print('   - Vistas: ${viewsResult.length}');
          print('   - Favoritos: ${favoritesResult.length}');
        } catch (e) {
          // Si falla Supabase, no pasa nada - ya está encolado para sincronizar
          print('❌ Error eliminando de Supabase: $e');
          print('Stack trace: ${StackTrace.current}');
        }
      } else {
        print('📴 Offline - eliminación encolada para cuando haya conexión');
      }
    } catch (e) {
      print('❌ Error crítico eliminando libro: $e');
      throw Exception('Error al eliminar libro: $e');
    }
  }

  /// Sincroniza libros locales (con ID local_*) a Supabase
  Future<void> _syncLocalBooks(String? userId) async {
    if (userId == null) return;
    
    final localDataSource = sl<BooksLocalDataSource>();
    
    try {
      print('🔄 Verificando libros locales para sincronizar...');
      
      // Obtener libros locales (con ID local_*)
      final cachedBooks = await localDataSource.getCachedBooks(authorId: userId);
      final localBooks = cachedBooks.where((book) => 
        book.id.startsWith('local_')
      ).toList();
      
      if (localBooks.isEmpty) {
        print('✅ No hay libros locales pendientes de sincronizar');
        return;
      }
      
      print('📤 Sincronizando ${localBooks.length} libro(s) local(es) a Supabase...');
      
      for (final localBook in localBooks) {
        try {
          print('📤 Sincronizando libro: "${localBook.title}" (${localBook.id})');
          
          // Crear el libro en Supabase
          final bookData = {
            'author_id': localBook.authorId,
            'title': localBook.title,
            'description': localBook.description,
            'category': localBook.category,
            'cover_path': localBook.coverPath,
            'created_at': DateTime.now().toIso8601String(),
          };
          
          final createdBookData = await _client
              .from(_booksTable)
              .insert(bookData)
              .select()
              .single();
          
          final newBookId = createdBookData['id'] as String;
          print('✅ Libro creado en Supabase con ID: $newBookId');
          
          // Crear capítulos en Supabase
          if (localBook.chapters.isNotEmpty) {
            print('📤 Sincronizando ${localBook.chapters.length} capítulo(s)...');
            
            for (final chapter in localBook.chapters) {
              final chapterData = {
                'book_id': newBookId,
                'chapter_order': chapter.order,
                'title': chapter.title,
                'content': chapter.content,
                'is_published': chapter.isPublished,
                'created_at': DateTime.now().toIso8601String(),
              };
              
              await _client.from(_chaptersTable).insert(chapterData);
            }
            
            print('✅ Capítulos sincronizados');
          }
          
          // Eliminar el libro local del caché
          await localDataSource.deleteCachedBook(localBook.id);
          print('🗑️ Libro local eliminado del caché: ${localBook.id}');
          
          print('🎉 Sincronización completada para: "${localBook.title}"');
        } catch (e) {
          print('❌ Error sincronizando libro "${localBook.title}": $e');
          // Continuar con el siguiente libro
        }
      }
      
      print('✅ Sincronización de libros locales completada');
    } catch (e) {
      print('❌ Error en _syncLocalBooks: $e');
    }
  }
}

class _BookMetrics {
  const _BookMetrics({
    required this.viewCount,
    required this.likeCount,
    required this.dislikeCount,
    required this.favoriteCount,
  });

  final int viewCount;
  final int likeCount;
  final int dislikeCount;
  final int favoriteCount;
}
