import '../repositories/chat_repository.dart';

class DeleteMessageUseCase {
  const DeleteMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call({
    required String messageId,
    required String senderId,
  }) {
    return _repository.deleteMessage(
      messageId: messageId,
      senderId: senderId,
    );
  }
}
