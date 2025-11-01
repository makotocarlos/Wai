import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_thread_entity.dart';

enum ChatThreadListStatus { initial, loading, loaded, error }

class ChatThreadListState extends Equatable {
  const ChatThreadListState({
    this.status = ChatThreadListStatus.initial,
    this.threads = const [],
    this.errorMessage,
  });

  final ChatThreadListStatus status;
  final List<ChatThreadEntity> threads;
  final String? errorMessage;

  ChatThreadListState copyWith({
    ChatThreadListStatus? status,
    List<ChatThreadEntity>? threads,
    String? errorMessage,
  }) {
    return ChatThreadListState(
      status: status ?? this.status,
      threads: threads ?? this.threads,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, threads, errorMessage];
}
