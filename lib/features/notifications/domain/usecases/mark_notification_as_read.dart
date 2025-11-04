import '../repositories/notifications_repository.dart';

class MarkNotificationAsReadUseCase {
  const MarkNotificationAsReadUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<void> call(String notificationId) =>
      _repository.markAsRead(notificationId);
}
