import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationsService {
  PushNotificationsService({
    required FirebaseMessaging messaging,
    required SupabaseClient client,
  })  : _messaging = messaging,
        _client = client;

  final FirebaseMessaging _messaging;
  final SupabaseClient _client;

  bool _initialized = false;

  void initialize() {
    if (_initialized || kIsWeb) {
      return;
    }
    _initialized = true;
    _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });
  }

  Future<bool> enablePushNotifications() async {
    initialize();

    if (kIsWeb) {
      debugPrint('Push notifications via FirebaseMessaging are not supported on web.');
      return false;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false,
      provisional: true,
      announcement: true,
      carPlay: false,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) {
      await _messaging.setAutoInitEnabled(false);
      return false;
    }

    await _messaging.setAutoInitEnabled(true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    return true;
  }

  Future<void> disablePushNotifications() async {
    if (kIsWeb) {
      return;
    }

    await _messaging.setAutoInitEnabled(false);
    final token = await _messaging.getToken();
    if (token != null) {
      await _unregisterToken(token);
    }

    try {
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('Failed to delete FCM token: $error');
    }
  }

  Future<void> syncTokenIfAuthorized() async {
    initialize();

    if (kIsWeb) {
      return;
    }

    final settings = await _messaging.getNotificationSettings();
    final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!authorized) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> _registerToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final data = {
      'user_id': userId,
      'token': token,
      'platform': _platformLabel(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.from('user_push_tokens').upsert(data, onConflict: 'token');
    } catch (error) {
      debugPrint('Failed to register push token: $error');
    }
  }

  Future<void> _unregisterToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      await _client
          .from('user_push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } catch (error) {
      debugPrint('Failed to unregister push token: $error');
    }
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
