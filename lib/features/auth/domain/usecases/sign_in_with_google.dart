import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  final AuthRepository repository;
  SignInWithGoogle(this.repository);

  Future<UserEntity> call() async {
    // Usamos el repositorio en lugar de Firebase directo
    return await repository.signInWithGoogle();
  }
}
