import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wappa_app/features/auth/presentation/bloc/auth_bloc.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  static const String routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SettingsTile(title: 'Perfil & cuenta'),
          const _SettingsTile(title: 'Notificaciones'),
          const _SettingsTile(title: 'Preferencias de lectura'),
          const _SettingsTile(
            title: 'Modo oscuro',
            subtitle: 'Automatico',
          ),
          const Divider(height: 32),
          const _SettingsTile(title: 'Privacidad & seguridad'),
          const _SettingsTile(title: 'Suscripcion Premium'),
          const _SettingsTile(
            title: 'Idioma de la historia',
            subtitle: 'Espanol',
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Cerrar sesion',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
