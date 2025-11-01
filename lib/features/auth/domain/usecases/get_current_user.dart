import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
	const GetCurrentUserUseCase(this._repository);

	final AuthRepository _repository;

	UserEntity? call() => _repository.currentUser();
}
