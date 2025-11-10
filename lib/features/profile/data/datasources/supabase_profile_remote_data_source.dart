import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/privacy_settings_entity.dart';
import '../../domain/entities/profile_entity.dart';
import 'profile_remote_data_source.dart';

class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _profilesTable = 'profiles';
  static const _followersTable = 'followers';
  static const _favoritesTable = 'favorites';
  static const _booksTable = 'books';
  static const _bookCommentsTable = 'book_comments';
  static const _chapterCommentsTable = 'chapter_comments';
  static const _avatarBucket = 'avatars';

  @override
  Future<ProfileEntity> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('User not authenticated');
    }
    return getProfile(user.id);
  }

  @override
  Future<ProfileEntity> getProfile(String userId) => _buildProfile(userId);

  @override
  Future<ProfileEntity> updateUsername(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('User not authenticated');
    }

    final updated = await _client
        .from(_profilesTable)
        .update({'username': username})
        .eq('id', user.id)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw PostgrestException(message: 'Unable to update username');
    }

    // Mantener metadata del usuario sincronizada en Supabase Auth para evitar
    // que procesos externos sobrescriban el valor de la tabla profiles.
    try {
      await _client.auth
          .updateUser(UserAttributes(data: {'username': username}));
    } catch (_) {
      // Si falla la actualización de metadata, continuamos igualmente porque
      // el valor en profiles ya fue guardado. El stream de perfiles seguirá
      // reportando el nombre correcto.
    }

    // Reflejar el nuevo nombre en libros y comentarios escritos por el usuario
    try {
      await Future.wait([
        _client
            .from(_booksTable)
            .update({'author_name': username})
            .eq('author_id', user.id),
        _client
            .from(_bookCommentsTable)
            .update({'username': username})
            .eq('user_id', user.id),
        _client
            .from(_chapterCommentsTable)
            .update({'username': username})
            .eq('user_id', user.id),
      ]);
    } catch (_) {
      // Ignoramos errores de propagación para no bloquear la actualización principal.
    }

    return _mapProfile(updated, isCurrentUser: true);
  }

  @override
  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('User not authenticated');
    }

    final path = '${user.id}/avatar.$fileExtension';

    await _client.storage.from(_avatarBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, cacheControl: '0'),
        );

    final baseUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    final publicUrl = '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from(_profilesTable)
        .update({'avatar_url': publicUrl}).eq('id', user.id);

    // Mantener metadata sincronizada con Supabase Auth para refrescar la UI global.
    try {
      await _client.auth
          .updateUser(UserAttributes(data: {'avatar_url': publicUrl}));
    } catch (_) {
      // Si falla, continuamos igual; la app seguirá mostrando el avatar desde profiles.
    }

    // Propagar avatar a comentarios existentes.
    try {
      await _client
          .from(_bookCommentsTable)
          .update({'user_avatar_url': publicUrl}).eq('user_id', user.id);
    } catch (_) {
      // Ignoramos errores para no bloquear al usuario.
    }

    try {
      await _client
          .from(_chapterCommentsTable)
          .update({'user_avatar_url': publicUrl}).eq('user_id', user.id);
    } catch (_) {
      // Ignoramos errores para no bloquear al usuario.
    }

    return publicUrl;
  }

  @override
  Future<void> followUser(String userId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const AuthException('User not authenticated');
    }

    await _client.from(_followersTable).insert({
      'follower_id': currentUser.id,
      'followed_id': userId,
    });
  }

  @override
  Future<void> unfollowUser(String userId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const AuthException('User not authenticated');
    }

    await _client.from(_followersTable).delete().match({
      'follower_id': currentUser.id,
      'followed_id': userId,
    });
  }

  @override
  Future<List<ProfileEntity>> getFollowers(String userId) async {
    final rows = await _client
        .from(_followersTable)
        .select('follower:profiles!followers_follower_id_fkey(*)')
        .eq('followed_id', userId);

    return rows
        .map<ProfileEntity>(
            (row) => _mapProfile(row['follower'] as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<ProfileEntity>> getFollowing(String userId) async {
    final rows = await _client
        .from(_followersTable)
        .select('followed:profiles!followers_followed_id_fkey(*)')
        .eq('follower_id', userId);

    return rows
        .map<ProfileEntity>(
            (row) => _mapProfile(row['followed'] as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<ProfileEntity>> getFavorites(String userId) async {
    // Obsoleto: la lista de favoritos ahora se maneja en BooksRepository.
    // Retornamos una lista vacía para mantener compatibilidad si es llamada.
    await _client
        .from(_favoritesTable)
        .select('id')
        .eq('user_id', userId);
    return const [];
  }

  @override
  Future<PrivacySettingsEntity> getPrivacySettings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('User not authenticated');
    }

    final response = await _client
        .from(_profilesTable)
        .select(
          'favorites_private, books_private, followers_private, following_private',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      throw PostgrestException(message: 'Profile not found');
    }

    return PrivacySettingsEntity.fromMap(response);
  }

  @override
  Future<PrivacySettingsEntity> updatePrivacySettings(
    PrivacySettingsEntity settings,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('User not authenticated');
    }

    final updated = await _client
        .from(_profilesTable)
        .update(settings.toMap())
        .eq('id', user.id)
        .select(
          'favorites_private, books_private, followers_private, following_private',
        )
        .maybeSingle();

    if (updated == null) {
      throw PostgrestException(message: 'Unable to update privacy settings');
    }

    return PrivacySettingsEntity.fromMap(updated);
  }

  @override
  Stream<ProfileEntity> watchProfile(String userId) {
    final subscriptions = <StreamSubscription<List<Map<String, dynamic>>>>[];
    late final StreamController<ProfileEntity> controller;

    Future<void> emitLatest() async {
      if (!controller.hasListener || controller.isClosed) {
        return;
      }

      try {
        final profile = await _buildProfile(userId);
        if (!controller.hasListener || controller.isClosed) {
          return;
        }
        controller.add(profile);
      } catch (error, stackTrace) {
        if (!controller.hasListener || controller.isClosed) {
          return;
        }
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<ProfileEntity>(
      onListen: () {
        subscriptions.add(
          _client
              .from(_profilesTable)
              .stream(primaryKey: ['id'])
              .eq('id', userId)
              .listen((_) => emitLatest()),
        );

        subscriptions.add(
          _client
              .from(_followersTable)
              .stream(primaryKey: ['id'])
              .eq('followed_id', userId)
              .listen((_) => emitLatest()),
        );

        subscriptions.add(
          _client
              .from(_followersTable)
              .stream(primaryKey: ['id'])
              .eq('follower_id', userId)
              .listen((_) => emitLatest()),
        );

        subscriptions.add(
          _client
              .from(_favoritesTable)
              .stream(primaryKey: ['id'])
              .eq('user_id', userId)
              .listen((_) => emitLatest()),
        );

        subscriptions.add(
          _client
              .from(_booksTable)
              .stream(primaryKey: ['id'])
              .eq('author_id', userId)
              .listen((_) => emitLatest()),
        );

        emitLatest();
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  Future<ProfileEntity> _buildProfile(String userId) async {
    final response = await _client
        .from(_profilesTable)
        .select('*')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      throw PostgrestException(message: 'Profile not found');
    }

  final followersCount = await _countFollowers(userId);
  final followingCount = await _countFollowing(userId);
  final favoritesCount = await _countFavorites(userId);
  final booksCount = await _countPublishedBooks(userId);

    final currentUserId = _client.auth.currentUser?.id;
    final isCurrentUser = currentUserId != null && currentUserId == userId;
    final isFollowing = currentUserId == null
        ? false
        : await _isFollowing(currentUserId, userId);

    return _mapProfile(
      response,
      isCurrentUser: isCurrentUser,
      followersCountOverride: followersCount,
      followingCountOverride: followingCount,
      favoritesCountOverride: favoritesCount,
      booksCountOverride: booksCount,
      isFollowingOverride: isFollowing,
    );
  }

  ProfileEntity _mapProfile(
    Map<String, dynamic> data, {
    bool? isCurrentUser,
    int? followersCountOverride,
    int? followingCountOverride,
    int? favoritesCountOverride,
    int? booksCountOverride,
    bool? isFollowingOverride,
  }) {
    return ProfileEntity(
      id: data['id'] as String,
      username: data['username'] as String? ?? 'Usuario',
      email: data['email'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      followersCount: followersCountOverride ?? data['followers_count'] as int? ?? 0,
      followingCount: followingCountOverride ?? data['following_count'] as int? ?? 0,
      favoritesCount: favoritesCountOverride ?? data['favorites_count'] as int? ?? 0,
      friendsCount: data['friends_count'] as int? ?? 0,
      booksCount: booksCountOverride ?? data['books_count'] as int? ?? 0,
      isFollowing: isFollowingOverride ?? data['is_following'] as bool? ?? false,
      isCurrentUser:
          isCurrentUser ?? (data['is_current_user'] as bool? ?? false),
      privacy: PrivacySettingsEntity.fromMap(data),
    );
  }

  Future<int> _countFollowers(String userId) async {
    final rows = await _client
        .from(_followersTable)
        .select('id')
        .eq('followed_id', userId);
    return rows.length;
  }

  Future<int> _countFollowing(String userId) async {
    final rows = await _client
        .from(_followersTable)
        .select('id')
        .eq('follower_id', userId);
    return rows.length;
  }

  Future<int> _countFavorites(String userId) async {
    final rows = await _client
        .from(_favoritesTable)
        .select('id')
        .eq('user_id', userId);
    return rows.length;
  }

  Future<int> _countPublishedBooks(String userId) async {
    final rows = await _client
        .from(_booksTable)
        .select(
          'id, published_chapter_index, book_chapters(is_published, chapter_order)',
        )
        .eq('author_id', userId);

    var total = 0;
    for (final dynamic entry in rows) {
      final data = entry as Map<String, dynamic>;
      final List<dynamic> chapters =
          (data['book_chapters'] as List<dynamic>?) ?? const [];

      final publishedByFlag = chapters.where((dynamic chapter) {
        final map = chapter as Map<String, dynamic>;
        final isPublished = map.containsKey('is_published')
            ? (map['is_published'] as bool?) ?? true
            : true;
        return isPublished;
      }).length;

      final totalChapters = chapters.length;
      final rawIndex = data['published_chapter_index'] as int?;
      final publishedByIndex = rawIndex == null || rawIndex < 0
          ? 0
          : math.min(totalChapters, rawIndex + 1);
      final publishedCount = math.max(publishedByFlag, publishedByIndex);

      if (publishedCount > 0) {
        total++;
      }
    }

    return total;
  }

  Future<bool> _isFollowing(String followerId, String targetId) async {
    if (followerId == targetId) {
      return false;
    }

    final existing = await _client
        .from(_followersTable)
        .select('id')
        .eq('follower_id', followerId)
        .eq('followed_id', targetId)
        .maybeSingle();

    return existing != null;
  }

  @override
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('User not authenticated');
    }

    final userId = user.id;
    print('🗑️ Iniciando eliminación de cuenta del usuario: $userId');

    try {
      // 1. Eliminar todos los libros del usuario (esto eliminará automáticamente
      //    capítulos, comentarios, likes, vistas gracias a CASCADE en la BD)
      print('📚 Eliminando libros y contenido relacionado...');
      await _client.from(_booksTable).delete().eq('author_id', userId);

      // 2. Eliminar comentarios del usuario en libros de otros
      print('💬 Eliminando comentarios en libros de otros...');
      await _client.from(_bookCommentsTable).delete().eq('user_id', userId);
      await _client.from(_chapterCommentsTable).delete().eq('user_id', userId);

      // 3. Eliminar likes del usuario en comentarios de otros
      print('❤️ Eliminando likes en comentarios...');
      await _client.from('book_comment_likes').delete().eq('user_id', userId);
      await _client.from('chapter_comment_likes').delete().eq('user_id', userId);

      // 4. Eliminar favoritos del usuario
      print('⭐ Eliminando favoritos...');
      await _client.from(_favoritesTable).delete().eq('user_id', userId);

      // 5. Eliminar seguidores (donde este usuario sigue a otros)
      print('👥 Eliminando relaciones de seguimiento...');
      await _client.from(_followersTable).delete().eq('follower_id', userId);

      // 6. Eliminar seguidos (donde otros siguen a este usuario)
      await _client.from(_followersTable).delete().eq('followed_id', userId);

      // 7. Eliminar mensajes directos del usuario
      print('💌 Eliminando mensajes directos...');
      await _client.from('direct_messages').delete().eq('sender_id', userId);
      
      // 8. Eliminar participación en hilos de conversación
      print('💬 Eliminando participación en conversaciones...');
      await _client.from('direct_thread_participants').delete().eq('profile_id', userId);
      
      // 9. Eliminar hilos de conversación creados por el usuario
      print('🗨️ Eliminando hilos de conversación creados...');
      await _client.from('direct_threads').delete().eq('created_by', userId);

      // 10. Eliminar notificaciones del usuario
      print('🔔 Eliminando notificaciones...');
      await _client.from('notifications').delete().eq('profile_id', userId);

      // 11. Eliminar tokens de push
      print('📱 Eliminando tokens de notificaciones push...');
      await _client.from('user_push_tokens').delete().eq('user_id', userId);

      // 12. Eliminar avatar del storage
      print('🖼️ Eliminando avatar...');
      try {
        final files = await _client.storage
            .from(_avatarBucket)
            .list(path: userId);
        
        if (files.isNotEmpty) {
          final filePaths = files.map((file) => '$userId/${file.name}').toList();
          await _client.storage.from(_avatarBucket).remove(filePaths);
        }
      } catch (e) {
        print('⚠️ Error eliminando avatar (puede no existir): $e');
        // Continuamos aunque falle, el avatar no es crítico
      }

      // 13. Eliminar el perfil
      print('👤 Eliminando perfil...');
      await _client.from(_profilesTable).delete().eq('id', userId);

      // 14. Finalmente, eliminar el usuario de Supabase Auth
      print('🔐 Eliminando usuario de autenticación...');
      try {
        // Intentamos con el RPC que elimina el usuario de auth.users
        await _client.rpc('delete_user');
        print('✅ Usuario eliminado de auth.users');
      } catch (e) {
        // Si no existe el RPC, cerramos sesión con scope global
        print('⚠️ RPC delete_user no disponible: $e');
        print('⚠️ IMPORTANTE: La cuenta de auth NO se eliminó. Ejecuta supabase_delete_user_function.sql');
      }
      
      // Siempre cerramos sesión con scope global para forzar logout
      print('🚪 Cerrando sesión...');
      await _client.auth.signOut(scope: SignOutScope.global);

      print('✅ Cuenta eliminada completamente');
    } catch (e) {
      print('❌ Error eliminando cuenta: $e');
      throw Exception('Error al eliminar la cuenta: $e');
    }
  }
}
