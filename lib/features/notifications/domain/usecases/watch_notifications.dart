import '../entities/notification_entity.dart';
import '../repositories/notifications_repository.dart';

class WatchNotificationsUseCase {
  const WatchNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  Stream<List<AppNotification>> call() => _repository.watchNotifications();
}
