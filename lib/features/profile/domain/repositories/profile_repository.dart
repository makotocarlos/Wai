import 'dart:typed_data';

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
  Stream<ProfileEntity> watchProfile(String userId);
}
