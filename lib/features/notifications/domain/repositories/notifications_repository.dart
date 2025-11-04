import '../entities/notification_entity.dart';

abstract class NotificationsRepository {
  Stream<List<AppNotification>> watchNotifications();

  Future<void> markAllAsRead();

  Future<void> markCategoryAsRead(NotificationType type);

  Future<void> markAsRead(String notificationId);
}
