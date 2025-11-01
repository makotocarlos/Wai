import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
	const UserEntity({
		required this.id,
		required this.email,
		required this.username,
		this.fullName,
		this.avatarUrl,
	});

	final String id;
	final String email;
	final String username;
	final String? fullName;
	final String? avatarUrl;

	@override
	List<Object?> get props => [id, email, username, fullName, avatarUrl];
}
