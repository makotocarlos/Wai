import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class WatchAuthStateUseCase {
	const WatchAuthStateUseCase(this._repository);

	final AuthRepository _repository;

	Stream<UserEntity?> call() => _repository.authStateChanges();
}
