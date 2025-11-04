import '../entities/chat_message_entity.dart';
import '../entities/chat_thread_entity.dart';

abstract class ChatRepository {
  Future<String> createOrFetchThread({
    required String currentUserId,
    required String otherUserId,
  });

  Stream<List<ChatThreadEntity>> watchThreads({
    required String userId,
  });

  Stream<List<ChatMessageEntity>> watchMessages({
    required String threadId,
  });

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String body,
    String? replyToMessageId,
  });

  Future<void> deleteMessage({
    required String messageId,
    required String senderId,
  });

  Future<ChatThreadEntity?> getThreadById({
    required String userId,
    required String threadId,
  });
}
