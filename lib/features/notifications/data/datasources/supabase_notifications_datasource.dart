import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationsDatasource {
  SupabaseNotificationsDatasource(this._client);

  final SupabaseClient _client;

  static const _table = 'notifications';

  Stream<List<Map<String, dynamic>>> watch() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }

    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
  .eq('profile_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> markAllAsRead() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    await _client
        .from(_table)
        .update({'read_at': now})
  .eq('profile_id', userId)
        .filter('read_at', 'is', null);
  }

  Future<void> markCategoryAsRead(String type) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    await _client
        .from(_table)
        .update({'read_at': now})
        .eq('type', type)
  .eq('profile_id', userId)
        .filter('read_at', 'is', null);
  }

  Future<void> markAsRead(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    await _client
        .from(_table)
        .update({'read_at': now})
        .eq('id', id)
  .eq('profile_id', userId)
        .filter('read_at', 'is', null);
  }
}
