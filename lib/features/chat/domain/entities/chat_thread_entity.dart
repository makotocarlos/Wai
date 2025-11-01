import 'package:equatable/equatable.dart';

import 'chat_participant_entity.dart';

class ChatThreadPreview extends Equatable {
  const ChatThreadPreview({
    required this.senderId,
    this.body,
    this.sentAt,
    this.isDeleted = false,
  });

  final String senderId;
  final String? body;
  final DateTime? sentAt;
  final bool isDeleted;

  @override
  List<Object?> get props => [senderId, body, sentAt, isDeleted];
}

class ChatThreadEntity extends Equatable {
  const ChatThreadEntity({
    required this.id,
    required this.createdAt,
    required this.participants,
    this.preview,
    this.updatedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ChatParticipantEntity> participants;
  final ChatThreadPreview? preview;

  @override
  List<Object?> get props => [id, createdAt, updatedAt, participants, preview];
}
