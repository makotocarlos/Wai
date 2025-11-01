import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
	const UserModel({
		required super.id,
		required super.email,
		required super.username,
		super.fullName,
		super.avatarUrl,
	});

	factory UserModel.fromSupabaseUser(User user) {
		final metadata = user.userMetadata ?? const <String, dynamic>{};
		final username = metadata['username'] as String? ??
				metadata['full_name'] as String? ??
				user.email?.split('@').first ??
				'Usuario';

		return UserModel(
			id: user.id,
			email: user.email ?? '',
			username: username,
			fullName: metadata['full_name'] as String?,
			avatarUrl: metadata['avatar_url'] as String? ?? metadata['picture'] as String?,
		);
	}

	factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
				id: json['id'] as String,
				email: json['email'] as String,
				username: json['username'] as String,
				fullName: json['full_name'] as String?,
				avatarUrl: json['avatar_url'] as String?,
			);

	Map<String, dynamic> toJson() => {
				'id': id,
				'email': email,
				'username': username,
				'full_name': fullName,
				'avatar_url': avatarUrl,
			};
}
