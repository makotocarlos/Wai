import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/usecases/delete_message.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';
import 'chat_conversation_state.dart';

class ChatConversationCubit extends Cubit<ChatConversationState> {
  ChatConversationCubit({
    required WatchMessagesUseCase watchMessages,
    required SendMessageUseCase sendMessage,
    required DeleteMessageUseCase deleteMessage,
    required String threadId,
    required String currentUserId,
  })  : _watchMessages = watchMessages,
        _sendMessage = sendMessage,
        _deleteMessage = deleteMessage,
        _threadId = threadId,
        _currentUserId = currentUserId,
        super(const ChatConversationState());

  final WatchMessagesUseCase _watchMessages;
  final SendMessageUseCase _sendMessage;
  final DeleteMessageUseCase _deleteMessage;
  final String _threadId;
  final String _currentUserId;

  StreamSubscription<List<ChatMessageEntity>>? _subscription;

  void start() {
    emit(state.copyWith(status: ChatConversationStatus.loading));
    _subscription?.cancel();
    _subscription = _watchMessages(threadId: _threadId).listen(
      (messages) {
        emit(
          state.copyWith(
            status: ChatConversationStatus.loaded,
            messages: messages,
            errorMessage: null,
          ),
        );
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: ChatConversationStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  Future<void> send(String text) async {
    if (state.isSending) {
      return;
    }

    final message = text.trim();
    if (message.isEmpty) {
      return;
    }

    emit(state.copyWith(isSending: true));
    try {
      await _sendMessage(
        threadId: _threadId,
        senderId: _currentUserId,
        body: message,
        replyToMessageId: state.replyingTo?.id,
      );
      emit(state.copyWith(isSending: false, clearReply: true));
    } catch (error) {
      emit(state.copyWith(isSending: false, errorMessage: error.toString()));
      rethrow;
    }
  }

  Future<void> deleteMessage(ChatMessageEntity message) async {
    if (message.sender.id != _currentUserId || message.isDeleted) {
      return;
    }

    try {
      await _deleteMessage(
        messageId: message.id,
        senderId: _currentUserId,
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
      rethrow;
    }
  }

  void setReply(ChatMessageEntity message) {
    if (message.isDeleted) {
      return;
    }
    emit(state.copyWith(replyingTo: message));
  }

  void clearReply() {
    emit(state.copyWith(clearReply: true));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
