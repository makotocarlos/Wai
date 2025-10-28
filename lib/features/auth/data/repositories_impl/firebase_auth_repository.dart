import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuthDatasource datasource;

  FirebaseAuthRepository({required this.datasource});

  @override
  Stream<UserEntity?> authStateChanges() {
    return datasource.authStateChanges();
  }

  @override
  UserEntity? currentUser() {
    return datasource.currentUser();
  }

  @override
  Future<UserEntity> signInWithEmail(String email, String password) {
    return datasource.signInWithEmail(email, password);
  }

  @override
  Future<UserEntity> signUpWithEmail(
    String email,
    String password, {
    required String username,
  }) {
    return datasource.signUpWithEmail(email, password, username: username);
  }

  @override
  Future<UserEntity> signInWithGoogle() {
    return datasource.signInWithGoogle();
  }

  @override
  Future<void> signOut() {
    return datasource.signOut();
  }

  @override
  Future<bool> isUsernameTaken(String username) {
    return datasource.isUsernameTaken(username);
  }
}
