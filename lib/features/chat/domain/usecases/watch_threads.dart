import '../entities/chat_thread_entity.dart';
import '../repositories/chat_repository.dart';

class WatchThreadsUseCase {
  const WatchThreadsUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<ChatThreadEntity>> call({required String userId}) {
    return _repository.watchThreads(userId: userId);
  }
}
