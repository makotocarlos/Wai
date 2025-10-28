// lib/features/auth/presentation/bloc/auth_bloc.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/watch_auth_state.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignIn signIn;
  final SignInWithGoogle signInWithGoogle;
  final SignUp signUp;
  final GetCurrentUser getCurrentUser;
  final SignOut signOut; // <-- nuevo
  final WatchAuthState watchAuthState;
  StreamSubscription<UserEntity?>? _authSubscription;

  AuthBloc({
    required this.signIn,
    required this.signInWithGoogle,
    required this.signUp,
    required this.getCurrentUser,
    required this.signOut,
    required this.watchAuthState,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthStatusChanged>(_onStatusChanged);
    on<SignInWithGoogleEvent>(_onGoogle);
    on<SignInWithEmailEvent>(_onEmailSignIn);
    on<SignUpWithEmailEvent>(_onEmailSignUp);
    on<SignOutEvent>(_onSignOut);

    _authSubscription = watchAuthState().listen((user) {
      add(AuthStatusChanged(user));
    });
  }

  Future<void> _onCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    if (state is! Authenticated) {
      emit(AuthLoading());
    }
    final user = getCurrentUser.call();
    if (user != null) {
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onStatusChanged(
      AuthStatusChanged event, Emitter<AuthState> emit) async {
    final user = event.user;
    if (user != null) {
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onGoogle(
      SignInWithGoogleEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await signInWithGoogle.call();
      String? infoMessage;
      try {
        final currentUser = fb.FirebaseAuth.instance.currentUser;
        final creationTime = currentUser?.metadata.creationTime;
        final lastSignInTime = currentUser?.metadata.lastSignInTime;
        final isFirstSignIn =
            creationTime != null && creationTime == lastSignInTime;

        if (isFirstSignIn && user.email != null && user.email!.isNotEmpty) {
          final providers = (currentUser?.providerData ?? [])
              .map((profile) => profile.providerId.toLowerCase())
              .toSet();

          final hasPasswordProvider = providers.contains('password');

          if (!hasPasswordProvider) {
            await fb.FirebaseAuth.instance
                .sendPasswordResetEmail(email: user.email!);
            infoMessage =
                'Te enviamos un correo para que definas una contraseña y puedas entrar también con "Ya tengo una cuenta".';
          }
        }
      } catch (e) {
        infoMessage =
            'Inicio con Google listo. Si quieres una contraseña, usa "¿Olvidaste tu contraseña?" y sigue el correo que te enviamos.';
      }

      emit(Authenticated(user, infoMessage: infoMessage));
    } on fb.FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? e.code));
    } catch (e) {
      emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onEmailSignIn(
      SignInWithEmailEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await signIn.call(event.email, event.password);
      emit(Authenticated(user));
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          emit(const AuthFailure('El correo no tiene un formato válido.'));
          break;
        case 'user-not-found':
          emit(const AuthFailure('No existe una cuenta con ese correo.'));
          break;
        case 'wrong-password':
        case 'invalid-credential':
          emit(const AuthFailure(
              'Correo o contraseña incorrectos. Si creaste la cuenta con Google, usa ese botón para entrar.'));
          break;
        case 'user-disabled':
          emit(const AuthFailure('La cuenta está deshabilitada.'));
          break;
        default:
          emit(AuthFailure(e.message ?? e.code));
      }
    } catch (e) {
      emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onEmailSignUp(
      SignUpWithEmailEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final user = await signUp.call(
        email: event.email,
        password: event.password,
        username: event.username,
      );

      emit(Authenticated(
        user,
        infoMessage:
            'Te enviamos un correo para que verifiques tu dirección antes de comenzar.',
      ));
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        emit(AuthFailure('La contraseña es muy débil'));
      } else if (e.code == 'email-already-in-use') {
        emit(AuthFailure('El correo ya está en uso'));
      } else {
        emit(AuthFailure(e.message ?? e.code));
      }
    } catch (e) {
      emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSignOut(SignOutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await signOut.call();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure('Error al cerrar sesión: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
