import 'package:equatable/equatable.dart';

import '../../domain/entities/profile_entity.dart';

enum ProfileConnectionsStatus { initial, loading, loaded, error }

class ProfileConnectionsState extends Equatable {
  const ProfileConnectionsState({
    this.status = ProfileConnectionsStatus.initial,
    this.profiles = const [],
    this.errorMessage,
  });

  final ProfileConnectionsStatus status;
  final List<ProfileEntity> profiles;
  final String? errorMessage;

  ProfileConnectionsState copyWith({
    ProfileConnectionsStatus? status,
    List<ProfileEntity>? profiles,
    String? errorMessage,
  }) {
    return ProfileConnectionsState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, profiles, errorMessage];
}
