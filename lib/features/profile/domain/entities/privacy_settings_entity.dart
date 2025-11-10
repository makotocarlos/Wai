import 'package:equatable/equatable.dart';

class PrivacySettingsEntity extends Equatable {
  const PrivacySettingsEntity({
    this.favoritesPrivate = false,
    this.booksPrivate = false,
    this.followersPrivate = false,
    this.followingPrivate = false,
  });

  final bool favoritesPrivate;
  final bool booksPrivate;
  final bool followersPrivate;
  final bool followingPrivate;

  PrivacySettingsEntity copyWith({
    bool? favoritesPrivate,
    bool? booksPrivate,
    bool? followersPrivate,
    bool? followingPrivate,
  }) {
    return PrivacySettingsEntity(
      favoritesPrivate: favoritesPrivate ?? this.favoritesPrivate,
      booksPrivate: booksPrivate ?? this.booksPrivate,
      followersPrivate: followersPrivate ?? this.followersPrivate,
      followingPrivate: followingPrivate ?? this.followingPrivate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'favorites_private': favoritesPrivate,
      'books_private': booksPrivate,
      'followers_private': followersPrivate,
      'following_private': followingPrivate,
    };
  }

  factory PrivacySettingsEntity.fromMap(Map<String, dynamic> map) {
    return PrivacySettingsEntity(
      favoritesPrivate: map['favorites_private'] as bool? ?? false,
      booksPrivate: map['books_private'] as bool? ?? false,
      followersPrivate: map['followers_private'] as bool? ?? false,
      followingPrivate: map['following_private'] as bool? ?? false,
    );
  }

  static const PrivacySettingsEntity defaults = PrivacySettingsEntity();

  @override
  List<Object?> get props => [
        favoritesPrivate,
        booksPrivate,
        followersPrivate,
        followingPrivate,
      ];
}
