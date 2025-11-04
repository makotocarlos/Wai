import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../services/notification/notification_preferences.dart';
import '../../../../services/notification/push_notifications_service.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _pushEnabled = false;
  late final PushNotificationsService _pushService;

  @override
  void initState() {
    super.initState();
    _pushService = sl<PushNotificationsService>()..initialize();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final enabled = await NotificationPreferences.isPushEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _pushEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _onTogglePush(bool value) async {
    if (_isSaving) {
      return;
    }

    final previousValue = _pushEnabled;
    setState(() {
      _pushEnabled = value;
      _isSaving = true;
    });

    try {
      if (value) {
        final granted = await _pushService.enablePushNotifications();
        if (!granted) {
          await NotificationPreferences.setPushEnabled(false);
          if (!mounted) {
            return;
          }
          setState(() {
            _pushEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No pudimos activar las notificaciones push. Revisa los permisos del sistema.',
              ),
            ),
          );
          return;
        }

        await NotificationPreferences.setPromptShown();
        await NotificationPreferences.setPushEnabled(true);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificaciones push activadas.')),
        );
      } else {
        await _pushService.disablePushNotifications();
        await NotificationPreferences.setPushEnabled(false);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificaciones push desactivadas.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pushEnabled = previousValue;
      });
      await NotificationPreferences.setPushEnabled(previousValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos actualizar tus preferencias: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Notificaciones push'),
                  subtitle: const Text(
                    'Activa alertas en tu dispositivo cuando recibas nuevos seguidores, mensajes y capítulos.',
                  ),
                  value: _pushEnabled,
                  onChanged: _isSaving ? null : _onTogglePush,
                ),
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Puedes seguir consultando las notificaciones desde la app aun si desactivas las push.',
                  ),
                ),
              ],
            ),
    );
  }
}
