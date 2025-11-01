import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  const ProfileEntity({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.favoritesCount = 0,
    this.friendsCount = 0,
    this.booksCount = 0,
    this.isFollowing = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final int favoritesCount;
  final int friendsCount;
  final int booksCount;
  final bool isFollowing;
  final bool isCurrentUser;

  ProfileEntity copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    int? followersCount,
    int? followingCount,
    int? favoritesCount,
    int? friendsCount,
    int? booksCount,
    bool? isFollowing,
    bool? isCurrentUser,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      friendsCount: friendsCount ?? this.friendsCount,
      booksCount: booksCount ?? this.booksCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        avatarUrl,
        followersCount,
        followingCount,
        favoritesCount,
        friendsCount,
        booksCount,
        isFollowing,
        isCurrentUser,
      ];
}
