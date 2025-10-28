import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/comment_entity.dart';

class CommentModel extends CommentEntity {
  CommentModel({
    required super.id,
    required super.userId,
    required super.userName,
    super.userPhotoUrl,
    required super.content,
    required super.createdAt,
    super.likes,
    super.dislikes,
    super.parentId,
  });

  factory CommentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CommentModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Usuario',
  userPhotoUrl: data['userPhotoUrl'] as String?,
      content: data['content'] as String? ?? '',
      createdAt: _timestampToDate(data['createdAt']),
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      dislikes: (data['dislikes'] as num?)?.toInt() ?? 0,
      parentId: data['parentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
  'userPhotoUrl': userPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'dislikes': dislikes,
      'parentId': parentId,
    };
  }

  static DateTime _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}
