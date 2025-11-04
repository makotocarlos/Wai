import '../repositories/notifications_repository.dart';

class MarkAllNotificationsAsReadUseCase {
  const MarkAllNotificationsAsReadUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<void> call() => _repository.markAllAsRead();
}
