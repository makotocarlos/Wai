import '../entities/notification_entity.dart';
import '../repositories/notifications_repository.dart';

class MarkNotificationsCategoryAsReadUseCase {
  const MarkNotificationsCategoryAsReadUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<void> call(NotificationType type) =>
      _repository.markCategoryAsRead(type);
}
