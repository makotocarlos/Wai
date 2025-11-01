import '../repositories/chat_repository.dart';

class CreateOrFetchThreadUseCase {
  const CreateOrFetchThreadUseCase(this._repository);

  final ChatRepository _repository;

  Future<String> call({
    required String currentUserId,
    required String otherUserId,
  }) {
    return _repository.createOrFetchThread(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
  }
}
