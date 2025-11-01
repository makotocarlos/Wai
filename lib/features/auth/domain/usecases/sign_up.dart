import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
	const SignUpUseCase(this._repository);

	final AuthRepository _repository;

	Future<UserEntity> call(
		String email,
		String password, {
		required String username,
	}) {
		return _repository.signUpWithEmail(
			email,
			password,
			username: username,
		);
	}
}
