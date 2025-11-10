import '../repositories/profile_repository.dart';

/// Use case para eliminar la cuenta del usuario actual.
/// 
/// Esto eliminará TODOS los datos del usuario:
/// - Libros publicados (y sus capítulos, comentarios, likes, vistas)
/// - Comentarios en otros libros
/// - Likes y favoritos
/// - Seguidores y seguidos
/// - Mensajes directos
/// - Notificaciones
/// - Perfil completo
class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);

  final ProfileRepository _repository;

  Future<void> call() {
    return _repository.deleteAccount();
  }
}
