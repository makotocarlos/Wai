import '../repositories/chat_repository.dart';

class SendMessageUseCase {
  const SendMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call({
    required String threadId,
    required String senderId,
    required String body,
    String? replyToMessageId,
  }) {
    return _repository.sendMessage(
      threadId: threadId,
      senderId: senderId,
      body: body,
      replyToMessageId: replyToMessageId,
    );
  }
}
