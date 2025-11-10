import 'dart:typed_data';

import '../entities/privacy_settings_entity.dart';
import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity> fetchProfile(String userId);
  Future<ProfileEntity> fetchCurrentProfile();
  Future<ProfileEntity> updateUsername(String username);
  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });
  Future<void> followUser(String userId);
  Future<void> unfollowUser(String userId);
  Future<List<ProfileEntity>> fetchFollowers(String userId);
  Future<List<ProfileEntity>> fetchFollowing(String userId);
  Future<List<ProfileEntity>> fetchFavorites(String userId);
  Future<PrivacySettingsEntity> fetchPrivacySettings();
  Future<PrivacySettingsEntity> updatePrivacySettings(
    PrivacySettingsEntity settings,
  );
  Stream<ProfileEntity> watchProfile(String userId);
  
  /// Elimina la cuenta del usuario actual y todos sus datos asociados.
  /// Esto incluye: libros, capítulos, comentarios, likes, favoritos,
  /// seguidores, seguidos, mensajes, notificaciones y perfil.
  Future<void> deleteAccount();
}
