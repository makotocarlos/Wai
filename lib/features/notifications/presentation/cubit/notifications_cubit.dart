import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/delete_all_notifications.dart';
import '../../domain/usecases/mark_all_notifications_as_read.dart';
import '../../domain/usecases/mark_notification_as_read.dart';
import '../../domain/usecases/mark_notifications_category_as_read.dart';
import '../../domain/usecases/watch_notifications.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required WatchNotificationsUseCase watchNotifications,
    required MarkAllNotificationsAsReadUseCase markAllNotificationsAsRead,
    required MarkNotificationsCategoryAsReadUseCase markCategoryAsRead,
    required MarkNotificationAsReadUseCase markNotificationAsRead,
    required DeleteAllNotificationsUseCase deleteAllNotifications,
  })  : _watchNotifications = watchNotifications,
        _markAllNotificationsAsRead = markAllNotificationsAsRead,
        _markCategoryAsRead = markCategoryAsRead,
        _markNotificationAsRead = markNotificationAsRead,
        _deleteAllNotifications = deleteAllNotifications,
        super(const NotificationsState());

  final WatchNotificationsUseCase _watchNotifications;
  final MarkAllNotificationsAsReadUseCase _markAllNotificationsAsRead;
  final MarkNotificationsCategoryAsReadUseCase _markCategoryAsRead;
  final MarkNotificationAsReadUseCase _markNotificationAsRead;
  final DeleteAllNotificationsUseCase _deleteAllNotifications;

  StreamSubscription<List<AppNotification>>? _subscription;

  void start() {
    emit(state.copyWith(status: NotificationsStatus.loading));

    _subscription?.cancel();
    _subscription = _watchNotifications().listen(
      (notifications) {
        emit(
          state.copyWith(
            status: NotificationsStatus.loaded,
            notifications: notifications,
            errorMessage: null,
          ),
        );
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: NotificationsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  Future<void> markAllAsRead() => _markAllNotificationsAsRead();

  Future<void> markCategoryAsRead(NotificationCategory category) =>
      _markCategoryAsRead(category.toNotificationType());

  Future<void> markNotificationAsRead(String notificationId) =>
      _markNotificationAsRead(notificationId);

  Future<void> deleteAllNotifications() async {
    print('🗑️ Eliminando todas las notificaciones...');
    try {
      await _deleteAllNotifications();
      print('✅ Todas las notificaciones eliminadas');
      
      // Forzar actualización inmediata del estado
      print('🔄 Actualizando estado a lista vacía...');
      emit(
        state.copyWith(
          notifications: [],
          status: NotificationsStatus.loaded,
        ),
      );
      print('✅ Estado actualizado correctamente');
    } catch (e) {
      print('❌ Error eliminando notificaciones: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
