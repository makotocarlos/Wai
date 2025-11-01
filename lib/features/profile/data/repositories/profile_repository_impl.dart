import 'dart:typed_data';

import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remoteDataSource);

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<ProfileEntity> fetchCurrentProfile() =>
      _remoteDataSource.getCurrentProfile();

  @override
  Future<ProfileEntity> fetchProfile(String userId) =>
      _remoteDataSource.getProfile(userId);

  @override
  Future<ProfileEntity> updateUsername(String username) =>
      _remoteDataSource.updateUsername(username);

  @override
  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) =>
      _remoteDataSource.uploadAvatar(
        bytes: bytes,
        fileExtension: fileExtension,
      );

  @override
  Future<void> followUser(String userId) =>
      _remoteDataSource.followUser(userId);

  @override
  Future<void> unfollowUser(String userId) =>
      _remoteDataSource.unfollowUser(userId);

  @override
  Future<List<ProfileEntity>> fetchFollowers(String userId) =>
      _remoteDataSource.getFollowers(userId);

  @override
  Future<List<ProfileEntity>> fetchFollowing(String userId) =>
      _remoteDataSource.getFollowing(userId);

  @override
  Future<List<ProfileEntity>> fetchFavorites(String userId) =>
      _remoteDataSource.getFavorites(userId);

  @override
  Stream<ProfileEntity> watchProfile(String userId) =>
      _remoteDataSource.watchProfile(userId);
}
