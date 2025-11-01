part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
	const AuthEvent();

	@override
	List<Object?> get props => [];
}

class AuthInitialize extends AuthEvent {
	const AuthInitialize();
}

class AuthStatusChanged extends AuthEvent {
	const AuthStatusChanged(this.user);

	final UserEntity? user;

	@override
	List<Object?> get props => [user];
}

class AuthSignInRequested extends AuthEvent {
	const AuthSignInRequested({
		required this.email,
		required this.password,
	});

	final String email;
	final String password;

	@override
	List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
	const AuthSignUpRequested({
		required this.email,
		required this.password,
		required this.username,
	});

	final String email;
	final String password;
	final String username;

	@override
	List<Object?> get props => [email, password, username];
}

class AuthSignOutRequested extends AuthEvent {
	const AuthSignOutRequested();
}

class AuthSendPasswordResetRequested extends AuthEvent {
	const AuthSendPasswordResetRequested(this.email);

	final String email;

	@override
	List<Object?> get props => [email];
}
