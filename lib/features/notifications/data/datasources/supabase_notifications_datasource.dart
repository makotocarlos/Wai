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

  Future<void> deleteAllNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      print('❌ No hay usuario autenticado');
      throw Exception('Usuario no autenticado');
    }
    
    print('🗑️ Eliminando todas las notificaciones del usuario: $userId');
    
    try {
      // Primero obtener todas las notificaciones del usuario
      final notificationsResponse = await _client
          .from(_table)
          .select('id')
          .eq('profile_id', userId);
      
      final notificationIds = (notificationsResponse as List)
          .map((n) => n['id'] as String)
          .toList();
      
      print('📊 Notificaciones encontradas: ${notificationIds.length}');
      
      if (notificationIds.isEmpty) {
        print('ℹ️ No hay notificaciones para eliminar');
        return;
      }
      
      // ELIMINACIÓN UNO POR UNO (más confiable)
      print('🔄 Eliminando notificaciones una por una...');
      int deleted = 0;
      int failed = 0;
      
      for (int i = 0; i < notificationIds.length; i++) {
        final id = notificationIds[i];
        try {
          await _client
              .from(_table)
              .delete()
              .eq('id', id)
              .eq('profile_id', userId);
          deleted++;
          print('✅ Eliminada notificación ${i + 1}/${notificationIds.length}');
        } catch (e) {
          failed++;
          print('❌ Error eliminando notificación $id: $e');
        }
        
        // Pequeña pausa para no saturar
        if (i < notificationIds.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      print('📊 Resultado: $deleted eliminadas, $failed fallidas');
      
      // Verificar que se eliminaron
      await Future.delayed(const Duration(milliseconds: 300)); // Esperar a que Supabase procese
      
      final remainingResponse = await _client
          .from(_table)
          .select('id')
          .eq('profile_id', userId);
      
      final remaining = (remainingResponse as List).length;
      
      if (remaining > 0) {
        print('⚠️ Aún quedan $remaining notificaciones después de eliminar');
        print('⚠️ Esto indica que las políticas RLS de Supabase no permiten DELETE');
        print('⚠️ Ejecuta el archivo: supabase_notifications_delete_policy.sql');
        throw Exception(
          'No se pudieron eliminar las notificaciones.\n'
          'Problema: Falta política RLS para DELETE en Supabase.\n'
          'Solución: Ejecuta el archivo supabase_notifications_delete_policy.sql en tu dashboard de Supabase.'
        );
      } else {
        print('✅ Todas las notificaciones eliminadas correctamente');
      }
    } catch (e, stackTrace) {
      print('❌ Error al eliminar notificaciones: $e');
      print('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }
}
