import '../repositories/auth_repository.dart';

class CheckUsernameExists {
  final AuthRepository repository;

  CheckUsernameExists(this.repository);

  Future<bool> call(String username) async {
    return await repository.isUsernameTaken(username);
  }
}
