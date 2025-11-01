import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message_entity.dart';

enum ChatConversationStatus { initial, loading, loaded, error }

class ChatConversationState extends Equatable {
  const ChatConversationState({
    this.status = ChatConversationStatus.initial,
    this.messages = const [],
    this.errorMessage,
    this.replyingTo,
    this.isSending = false,
  });

  final ChatConversationStatus status;
  final List<ChatMessageEntity> messages;
  final String? errorMessage;
  final ChatMessageEntity? replyingTo;
  final bool isSending;

  ChatConversationState copyWith({
    ChatConversationStatus? status,
    List<ChatMessageEntity>? messages,
    String? errorMessage,
    ChatMessageEntity? replyingTo,
    bool? isSending,
    bool clearReply = false,
  }) {
    return ChatConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props => [status, messages, errorMessage, replyingTo, isSending];
}
