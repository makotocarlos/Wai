import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository repository;
  GetCurrentUser(this.repository);

  UserEntity? call() {
    return repository.currentUser();
  }
}
