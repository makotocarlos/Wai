import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/email_confirmation_required_exception.dart';
import '../models/user_model.dart';

const String _supabaseOAuthRedirectUrl = String.fromEnvironment(
  'SUPABASE_OAUTH_REDIRECT_URL',
  defaultValue: 'io.supabase.wai://login-callback',
);

const String _supabaseResetRedirectUrl = String.fromEnvironment(
  'SUPABASE_RESET_REDIRECT_URL',
  defaultValue: 'https://leupcmmvwqtgbisnrhph.supabase.co/auth/v1/callback',
);

class SupabaseAuthDatasource {
  SupabaseAuthDatasource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Stream<UserModel?> authStateChanges() async* {
    yield currentUser();
    await for (final event in _client.auth.onAuthStateChange) {
      final user = event.session?.user;
      if (user != null) {
        unawaited(_ensureProfile(user));
        yield UserModel.fromSupabaseUser(user);
      } else {
        yield null;
      }
    }
  }

  UserModel? currentUser() {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabaseUser(user);
  }

  Future<UserModel> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
  throw AuthException('No se pudo iniciar sesion.');
    }

    unawaited(_ensureProfile(user));
    return UserModel.fromSupabaseUser(user);
  }

  Future<UserModel> signUpWithEmail(
    String email,
    String password, {
    required String username,
  }) async {
    final exists = await isUsernameTaken(username);
    if (exists) {
  throw AuthException('El nombre de usuario ya esta en uso');
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
      },
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw const EmailConfirmationRequiredException(
        'Te enviamos un correo para activar tu cuenta. Revisa tu bandeja y sigue el enlace.',
      );
    }

    await _ensureProfile(user, username: username);
    return UserModel.fromSupabaseUser(user);
  }

  Future<UserModel> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _supabaseOAuthRedirectUrl,
    );

    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException(
        'Completa el flujo de inicio de sesion en el navegador y vuelve a la app.',
      );
    }

    await _ensureProfile(user);
    return UserModel.fromSupabaseUser(user);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<bool> isUsernameTaken(String username) async {
    final data = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return data != null;
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: _supabaseResetRedirectUrl,
    );
  }

  Future<void> _ensureProfile(
    User user, {
    String? username,
  }) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final currentUsername = username ?? metadata['username'] as String?;
    final name = currentUsername ??
        metadata['full_name'] as String? ??
        user.email?.split('@').first ??
        'Usuario';

    try {
      await _client.from('profiles').upsert(
            {
              'id': user.id,
              'email': user.email,
              'username': name,
              'full_name': metadata['full_name'],
              'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
            },
            onConflict: 'id',
          );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[Supabase] No se pudo sincronizar el perfil: ${error.message}');
      debugPrint('$stackTrace');
    }
  }
}
