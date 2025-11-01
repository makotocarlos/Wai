import 'package:equatable/equatable.dart';

class ChatParticipantEntity extends Equatable {
  const ChatParticipantEntity({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String email;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, username, email, avatarUrl];
}
