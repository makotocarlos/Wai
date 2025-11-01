import 'package:equatable/equatable.dart';

import 'chat_participant_entity.dart';

class ChatMessageReference extends Equatable {
  const ChatMessageReference({
    required this.id,
    required this.sender,
    this.body,
    this.deletedAt,
  });

  final String id;
  final ChatParticipantEntity sender;
  final String? body;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [id, sender, body, deletedAt];
}

class ChatMessageEntity extends Equatable {
  const ChatMessageEntity({
    required this.id,
    required this.threadId,
    required this.sender,
    this.body,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.replyTo,
  });

  final String id;
  final String threadId;
  final ChatParticipantEntity sender;
  final String? body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final ChatMessageReference? replyTo;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
        id,
        threadId,
        sender,
        body,
        createdAt,
        updatedAt,
        deletedAt,
        replyTo,
      ];
}
