import 'package:equatable/equatable.dart';

class CommentEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String content;
  final DateTime createdAt;
  final int likes;
  final int dislikes;
  final String? parentId;

  const CommentEntity({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    this.likes = 0,
    this.dislikes = 0,
    this.parentId,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
  userPhotoUrl,
        content,
        createdAt,
        likes,
        dislikes,
        parentId,
      ];
}
