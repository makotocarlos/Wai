import 'package:equatable/equatable.dart';

import '../../domain/entities/notification_entity.dart';

enum NotificationsStatus { initial, loading, loaded, error }

enum NotificationCategory {
  bookLikes,
  followers,
  bookComments,
  chapterComments,
  chat,
  newChapters,
}

extension NotificationCategoryType on NotificationCategory {
  NotificationType toNotificationType() {
    switch (this) {
      case NotificationCategory.bookLikes:
        return NotificationType.bookLike;
      case NotificationCategory.followers:
        return NotificationType.newFollower;
      case NotificationCategory.bookComments:
        return NotificationType.bookComment;
      case NotificationCategory.chapterComments:
        return NotificationType.chapterComment;
      case NotificationCategory.chat:
        return NotificationType.chatMessage;
      case NotificationCategory.newChapters:
        return NotificationType.newChapter;
    }
  }

  String get label {
    switch (this) {
      case NotificationCategory.bookLikes:
        return 'Me gusta';
      case NotificationCategory.followers:
        return 'Seguidores';
      case NotificationCategory.bookComments:
        return 'Comentarios de libros';
      case NotificationCategory.chapterComments:
        return 'Comentarios de capítulos';
      case NotificationCategory.chat:
        return 'Mensajes';
      case NotificationCategory.newChapters:
        return 'Nuevos capítulos';
    }
  }
}

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const <AppNotification>[],
    this.errorMessage,
  });

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final String? errorMessage;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    String? errorMessage,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, notifications, errorMessage];

  int unreadCountByCategory(NotificationCategory category) {
    final type = category.toNotificationType();
    return notifications.where((item) => !item.isRead && item.type == type).length;
  }

  Map<NotificationCategory, List<AppNotification>> grouped() {
    final map = <NotificationCategory, List<AppNotification>>{};
    for (final category in NotificationCategory.values) {
      map[category] = <AppNotification>[];
    }

    for (final notification in notifications) {
      final category = _categoryFromType(notification.type);
      map[category]!.add(notification);
    }
    return map;
  }

  NotificationCategory _categoryFromType(NotificationType type) {
    switch (type) {
      case NotificationType.bookLike:
        return NotificationCategory.bookLikes;
      case NotificationType.newFollower:
        return NotificationCategory.followers;
      case NotificationType.bookComment:
        return NotificationCategory.bookComments;
      case NotificationType.chapterComment:
        return NotificationCategory.chapterComments;
      case NotificationType.chatMessage:
        return NotificationCategory.chat;
      case NotificationType.newChapter:
        return NotificationCategory.newChapters;
    }
  }
}
