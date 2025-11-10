import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/supabase_notifications_datasource.dart';
import '../models/notification_model.dart';

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository({
    required SupabaseNotificationsDatasource datasource,
  }) : _datasource = datasource;

  final SupabaseNotificationsDatasource _datasource;

  @override
  Stream<List<AppNotification>> watchNotifications() {
    return _datasource.watch().map(
          (rows) => rows
              .map((row) => NotificationModel.fromMap(row))
              .toList(growable: false),
        );
  }

  @override
  Future<void> markAllAsRead() => _datasource.markAllAsRead();

  @override
  Future<void> markCategoryAsRead(NotificationType type) =>
      _datasource.markCategoryAsRead(type.value);

  @override
  Future<void> markAsRead(String notificationId) =>
      _datasource.markAsRead(notificationId);

  @override
  Future<void> deleteAllNotifications() =>
      _datasource.deleteAllNotifications();
}
