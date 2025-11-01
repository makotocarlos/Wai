import '../repositories/auth_repository.dart';

class CheckUsernameExistsUseCase {
	const CheckUsernameExistsUseCase(this._repository);

	final AuthRepository _repository;

	Future<bool> call(String username) => _repository.isUsernameTaken(username);
}
