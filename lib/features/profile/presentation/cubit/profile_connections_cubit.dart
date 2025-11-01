import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_connections_state.dart';

enum ProfileConnectionsType { followers, following, favorites }

class ProfileConnectionsCubit extends Cubit<ProfileConnectionsState> {
  ProfileConnectionsCubit(this._repository)
      : super(const ProfileConnectionsState());

  final ProfileRepository _repository;

  Future<void> loadConnections(
      String userId, ProfileConnectionsType type) async {
    emit(state.copyWith(status: ProfileConnectionsStatus.loading));
    try {
      final List<ProfileEntity> profiles;
      switch (type) {
        case ProfileConnectionsType.followers:
          profiles = await _repository.fetchFollowers(userId);
          break;
        case ProfileConnectionsType.following:
          profiles = await _repository.fetchFollowing(userId);
          break;
        case ProfileConnectionsType.favorites:
          profiles = const [];
          break;
      }
      emit(state.copyWith(
        status: ProfileConnectionsStatus.loaded,
        profiles: profiles,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: ProfileConnectionsStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }
}
