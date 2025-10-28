// lib/features/auth/domain/usecases/sign_out.dart
import '../repositories/auth_repository.dart';

class SignOut {
  final AuthRepository repository;
  SignOut(this.repository);

  Future<void> call() => repository.signOut();
}
