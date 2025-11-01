import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_auth_datasource.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required SupabaseAuthDatasource datasource})
      : _datasource = datasource;

  final SupabaseAuthDatasource _datasource;

  @override
  Stream<UserEntity?> authStateChanges() => _datasource.authStateChanges();

  @override
  UserEntity? currentUser() => _datasource.currentUser();

  @override
  Future<UserEntity> signInWithEmail(String email, String password) =>
      _datasource.signInWithEmail(email, password);

  @override
  Future<UserEntity> signUpWithEmail(
    String email,
    String password, {
    required String username,
  }) =>
      _datasource.signUpWithEmail(email, password, username: username);

  @override
  Future<UserEntity> signInWithGoogle() => _datasource.signInWithGoogle();

  @override
  Future<void> signOut() => _datasource.signOut();

  @override
  Future<bool> isUsernameTaken(String username) =>
      _datasource.isUsernameTaken(username);

  @override
  Future<void> sendPasswordReset(String email) =>
      _datasource.sendPasswordReset(email);
}
