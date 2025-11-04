import 'package:equatable/equatable.dart';

/// Enumeracion de los tipos soportados de notificacion dentro de la app.
enum NotificationType {
  bookLike,
  newFollower,
  bookComment,
  chapterComment,
  chatMessage,
  newChapter,
}

extension NotificationTypeMapper on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.bookLike:
        return 'book_like';
      case NotificationType.newFollower:
        return 'new_follower';
      case NotificationType.bookComment:
        return 'book_comment';
      case NotificationType.chapterComment:
        return 'chapter_comment';
      case NotificationType.chatMessage:
        return 'chat_message';
      case NotificationType.newChapter:
        return 'new_chapter';
    }
  }

  static NotificationType fromValue(String raw) {
    switch (raw) {
      case 'book_like':
        return NotificationType.bookLike;
      case 'new_follower':
        return NotificationType.newFollower;
      case 'book_comment':
        return NotificationType.bookComment;
      case 'chapter_comment':
        return NotificationType.chapterComment;
      case 'chat_message':
        return NotificationType.chatMessage;
      case 'new_chapter':
        return NotificationType.newChapter;
      default:
        return NotificationType.bookLike;
    }
  }
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final NotificationType type;
  final String? title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        body,
        createdAt,
        isRead,
        data,
      ];
}
