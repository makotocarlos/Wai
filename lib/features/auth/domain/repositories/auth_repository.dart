import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> authStateChanges();
  UserEntity? currentUser();
  Future<UserEntity> signInWithEmail(String email, String password);
  Future<UserEntity> signUpWithEmail(String email, String password, {required String username}); // ✅ ahora recibe username
  Future<UserEntity> signInWithGoogle();
  Future<void> signOut();

  Future<bool> isUsernameTaken(String username); // ✅ nuevo método
}

