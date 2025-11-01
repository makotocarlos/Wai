import '../entities/chat_message_entity.dart';
import '../repositories/chat_repository.dart';

class WatchMessagesUseCase {
  const WatchMessagesUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<ChatMessageEntity>> call({required String threadId}) {
    return _repository.watchMessages(threadId: threadId);
  }
}
