import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;
  StreamSubscription<ProfileEntity>? _profileSubscription;

  Future<void> loadProfile({String? userId}) async {
    emit(state.copyWith(status: ProfileStatus.loading));

    _profileSubscription?.cancel();

    try {
      final profile = userId != null
          ? await _repository.fetchProfile(userId)
          : await _repository.fetchCurrentProfile();

      emit(state.copyWith(status: ProfileStatus.loaded, profile: profile));

      final String watchId = userId ?? profile.id;
      _profileSubscription = _repository.watchProfile(watchId).listen(
        (updatedProfile) {
          emit(state.copyWith(status: ProfileStatus.loaded, profile: updatedProfile));
        },
        onError: (error) {
          emit(state.copyWith(
            status: ProfileStatus.error,
            errorMessage: error.toString(),
          ));
        },
      );
    } catch (error) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> updateUsername(String username) async {
    if (state.status == ProfileStatus.loading) return;
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final updated = await _repository.updateUsername(username);
      emit(state.copyWith(status: ProfileStatus.loaded, profile: updated));
    } catch (error) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> refreshProfile() async {
    final currentProfile = state.profile;
    if (currentProfile == null) {
      return;
    }

    try {
      final profile = currentProfile.isCurrentUser
          ? await _repository.fetchCurrentProfile()
          : await _repository.fetchProfile(currentProfile.id);
      emit(state.copyWith(status: ProfileStatus.loaded, profile: profile));
    } catch (error) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> changeAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    if (state.profile == null) return;
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final url = await _repository.uploadAvatar(
        bytes: bytes,
        fileExtension: fileExtension,
      );
      final updated = state.profile!.copyWith(avatarUrl: url);
      emit(state.copyWith(status: ProfileStatus.loaded, profile: updated));
    } catch (error) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> toggleFollow(ProfileEntity profile) async {
    if (profile.isCurrentUser) return;
    final isFollowing = profile.isFollowing;
    final previousProfile = state.profile;
    emit(state.copyWith(
      profile: state.profile?.copyWith(
        followersCount: state.profile!.followersCount + (isFollowing ? -1 : 1),
        isFollowing: !isFollowing,
      ),
    ));
    try {
      if (isFollowing) {
        await _repository.unfollowUser(profile.id);
      } else {
        await _repository.followUser(profile.id);
      }
    } catch (error) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: error.toString(),
        profile: previousProfile,
      ));
    }
  }

  @override
  Future<void> close() {
    _profileSubscription?.cancel();
    return super.close();
  }
}
