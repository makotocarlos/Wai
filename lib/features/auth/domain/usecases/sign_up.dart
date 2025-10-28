import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUp {
  final AuthRepository repository;
  SignUp(this.repository);

  /// Ahora recibe username y lo pasa al repositorio
  Future<UserEntity> call({
    required String email,
    required String password,
    required String username,
  }) async {
    // Primero validamos que el username no exista
    final usernameTaken = await repository.isUsernameTaken(username);
    if (usernameTaken) {
      throw Exception('El nombre de usuario ya está en uso');
    }

    // Validación mínima de contraseña (>= 8 caracteres)
    if (password.length < 8) {
      throw Exception('La contraseña debe tener al menos 8 caracteres');
    }

    // Registrar usuario
    return await repository.signUpWithEmail(
      email,
      password,
      username: username,
    );
  }
}
