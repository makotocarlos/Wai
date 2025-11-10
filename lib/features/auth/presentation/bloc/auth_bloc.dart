import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/email_confirmation_required_exception.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/send_password_reset.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/watch_auth_state.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
	AuthBloc({
		required SignInUseCase signIn,
		required SignUpUseCase signUp,
		required SignOutUseCase signOut,
		required WatchAuthStateUseCase watchAuthState,
		required GetCurrentUserUseCase getCurrentUser,
		required SendPasswordResetUseCase sendPasswordReset,
	})  : _signIn = signIn,
				_signUp = signUp,
				_signOut = signOut,
				_watchAuthState = watchAuthState,
				_getCurrentUser = getCurrentUser,
				_sendPasswordReset = sendPasswordReset,
				super(const AuthState()) {
		on<AuthInitialize>(_onInitialize);
		on<AuthStatusChanged>(_onStatusChanged);
		on<AuthSignInRequested>(_onSignInRequested);
		on<AuthSignUpRequested>(_onSignUpRequested);
		on<AuthSignOutRequested>(_onSignOutRequested);
		on<AuthSendPasswordResetRequested>(_onSendPasswordResetRequested);
	}

	final SignInUseCase _signIn;
	final SignUpUseCase _signUp;
	final SignOutUseCase _signOut;
	final WatchAuthStateUseCase _watchAuthState;
	final GetCurrentUserUseCase _getCurrentUser;
	final SendPasswordResetUseCase _sendPasswordReset;

	StreamSubscription<UserEntity?>? _subscription;

	Future<void> _onInitialize(
		AuthInitialize event,
		Emitter<AuthState> emit,
	) async {
		emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearInfo: true));

		final current = _getCurrentUser();
		if (current != null) {
			emit(
				state.copyWith(
					status: AuthStatus.authenticated,
					user: current,
					clearError: true,
					clearInfo: true,
				),
			);
		} else {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					clearUser: true,
					clearError: true,
					clearInfo: true,
				),
			);
		}

		await _subscription?.cancel();
		_subscription = _watchAuthState().listen(
			(user) => add(AuthStatusChanged(user)),
		);
	}

	void _onStatusChanged(
		AuthStatusChanged event,
		Emitter<AuthState> emit,
	) {
		if (event.user != null) {
			emit(
				state.copyWith(
					status: AuthStatus.authenticated,
					user: event.user,
					clearError: true,
					clearInfo: true,
				),
			);
		} else {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					clearUser: true,
					clearError: true,
					clearInfo: true,
				),
			);
		}
	}

	Future<void> _onSignInRequested(
		AuthSignInRequested event,
		Emitter<AuthState> emit,
	) async {
		emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearInfo: true));
		try {
			await _signIn(event.email, event.password);
		} on AuthException catch (error) {
			// Mejorar mensajes de error según el código de error
			String errorMessage;
			if (error.message.toLowerCase().contains('invalid login credentials') ||
					error.message.toLowerCase().contains('invalid_credentials')) {
				errorMessage = '❌ Correo o contraseña incorrectos. Verifica tus datos.';
			} else if (error.message.toLowerCase().contains('email not confirmed') ||
					error.message.toLowerCase().contains('email_not_confirmed')) {
				errorMessage = '📧 Debes verificar tu correo electrónico.\nRevisa tu bandeja de entrada y haz clic en el enlace de confirmación.';
			} else if (error.message.toLowerCase().contains('user not found')) {
				errorMessage = '❌ No existe una cuenta con este correo electrónico.';
			} else if (error.message.toLowerCase().contains('too many requests')) {
				errorMessage = '⏱️ Demasiados intentos. Espera un momento e intenta nuevamente.';
			} else {
				errorMessage = '❌ ${error.message}';
			}
			
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					errorMessage: errorMessage,
					clearInfo: true,
				),
			);
		} catch (error) {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					errorMessage: '❌ Ocurrio un error al iniciar sesion. Intenta nuevamente.',
					clearInfo: true,
				),
			);
		}
	}

	Future<void> _onSignUpRequested(
		AuthSignUpRequested event,
		Emitter<AuthState> emit,
	) async {
		emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearInfo: true));
		try {
			await _signUp(
				event.email,
				event.password,
				username: event.username,
			);
		} on EmailConfirmationRequiredException catch (error) {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					infoMessage: error.message,
					clearError: true,
				),
			);
		} on AuthException catch (error) {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					errorMessage: error.message,
					clearInfo: true,
				),
			);
		} catch (error) {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					errorMessage: 'Ocurrio un error al registrar la cuenta.',
					clearInfo: true,
				),
			);
		}
	}

	Future<void> _onSignOutRequested(
		AuthSignOutRequested event,
		Emitter<AuthState> emit,
	) async {
		emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearInfo: true));
		try {
			await _signOut();
		} catch (error) {
			emit(
				state.copyWith(
					status: AuthStatus.unauthenticated,
					errorMessage: 'No se pudo cerrar sesion. Intenta nuevamente.',
					clearInfo: true,
				),
			);
		}
	}

	Future<void> _onSendPasswordResetRequested(
		AuthSendPasswordResetRequested event,
		Emitter<AuthState> emit,
	) async {
		emit(state.copyWith(clearError: true, clearInfo: true));
		try {
			await _sendPasswordReset(event.email);
			emit(
				state.copyWith(
					infoMessage: 'Te enviamos un correo para restablecer la contrasena.',
					clearError: true,
				),
			);
		} on AuthException catch (error) {
			emit(
				state.copyWith(
					errorMessage: error.message,
					clearInfo: true,
				),
			);
		} catch (error) {
			emit(
				state.copyWith(
					errorMessage: 'No se pudo enviar el correo de recuperacion.',
					clearInfo: true,
				),
			);
		}
	}

	@override
	Future<void> close() async {
		await _subscription?.cancel();
		return super.close();
	}
}
