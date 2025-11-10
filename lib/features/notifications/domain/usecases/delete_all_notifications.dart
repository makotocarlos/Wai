import '../repositories/notifications_repository.dart';

class DeleteAllNotificationsUseCase {
  DeleteAllNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<void> call() => _repository.deleteAllNotifications();
}
