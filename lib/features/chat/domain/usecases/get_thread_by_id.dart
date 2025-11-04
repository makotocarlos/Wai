import '../entities/chat_thread_entity.dart';
import '../repositories/chat_repository.dart';

class GetThreadByIdUseCase {
  const GetThreadByIdUseCase(this._repository);

  final ChatRepository _repository;

  Future<ChatThreadEntity?> call({
    required String userId,
    required String threadId,
  }) {
    return _repository.getThreadById(userId: userId, threadId: threadId);
  }
}
