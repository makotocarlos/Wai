part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
	const AuthState({
		this.status = AuthStatus.initial,
		this.user,
		this.errorMessage,
		this.infoMessage,
	});

	final AuthStatus status;
	final UserEntity? user;
	final String? errorMessage;
	final String? infoMessage;

	AuthState copyWith({
		AuthStatus? status,
		UserEntity? user,
		bool clearUser = false,
		String? errorMessage,
		bool clearError = false,
		String? infoMessage,
		bool clearInfo = false,
	}) {
		return AuthState(
			status: status ?? this.status,
			user: clearUser ? null : user ?? this.user,
			errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
			infoMessage: clearInfo ? null : infoMessage ?? this.infoMessage,
		);
	}

	@override
	List<Object?> get props => [status, user, errorMessage, infoMessage];
}
