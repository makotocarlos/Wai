import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDatasource datasource;
  AuthRepositoryImpl(this.datasource);

  @override
  Stream<UserEntity?> authStateChanges() => datasource.authStateChanges();

  @override
  UserEntity? currentUser() => datasource.currentUser();

  @override
  Future<UserEntity> signInWithEmail(String email, String password) =>
      datasource.signInWithEmail(email, password);

  @override
  Future<UserEntity> signUpWithEmail(String email, String password, {required String username}) =>
      datasource.signUpWithEmail(email, password, username: username); // Pasamos username al datasource

  @override
  Future<UserEntity> signInWithGoogle() => datasource.signInWithGoogle();

  @override
  Future<void> signOut() => datasource.signOut();

  @override
  Future<bool> isUsernameTaken(String username) =>
      datasource.isUsernameTaken(username); // Implementamos
}
