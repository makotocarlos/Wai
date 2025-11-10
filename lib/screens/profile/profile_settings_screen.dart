import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wappa_app/features/auth/presentation/bloc/auth_bloc.dart';

import 'package:wappa_app/features/notifications/presentation/pages/notifications_settings_page.dart';
import 'package:wappa_app/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:wappa_app/screens/profile/profile_account_settings_page.dart';

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
          _SettingsTile(
            title: 'Perfil & cuenta',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileAccountSettingsPage(),
                ),
              );
            },
          ),
          _SettingsTile(
            title: 'Notificaciones',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsSettingsPage(),
                ),
              );
            },
          ),
          const _SettingsTile(title: 'Preferencias de lectura'),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              final isDarkMode = mode == ThemeMode.dark;
              return ListTile(
                title: const Text('Modo oscuro'),
                subtitle: Text(isDarkMode ? 'Activado' : 'Desactivado'),
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) =>
                      context.read<ThemeCubit>().toggleDarkMode(value),
                ),
                onTap: () =>
                    context.read<ThemeCubit>().toggleDarkMode(!isDarkMode),
              );
            },
          ),
          const Divider(height: 32),
          _SettingsTile(
            title: 'Privacidad & seguridad',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileAccountSettingsPage(),
                ),
              );
            },
          ),
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
  const _SettingsTile({required this.title, this.subtitle, this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
