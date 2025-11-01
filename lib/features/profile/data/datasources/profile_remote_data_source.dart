import 'dart:typed_data';

import '../../domain/entities/profile_entity.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileEntity> getProfile(String userId);
  Future<ProfileEntity> getCurrentProfile();
  Future<ProfileEntity> updateUsername(String username);
  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });
  Future<void> followUser(String userId);
  Future<void> unfollowUser(String userId);
  Future<List<ProfileEntity>> getFollowers(String userId);
  Future<List<ProfileEntity>> getFollowing(String userId);
  Future<List<ProfileEntity>> getFavorites(String userId);
  Stream<ProfileEntity> watchProfile(String userId);
}
