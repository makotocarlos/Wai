import '../../domain/entities/notification_entity.dart';

class NotificationModel extends AppNotification {
  NotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.body,
    required super.createdAt,
    required super.isRead,
    super.data = const <String, dynamic>{},
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    return NotificationModel(
      id: map['id'] as String,
      type: NotificationTypeMapper.fromValue(map['type'] as String),
      title: map['title'] as String?,
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isRead: map['read_at'] != null,
      data: rawData is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
    );
  }
}
