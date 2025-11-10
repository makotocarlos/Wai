import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wappa_app/core/di/injection.dart';
import 'package:wappa_app/features/profile/domain/entities/privacy_settings_entity.dart';
import 'package:wappa_app/features/profile/domain/usecases/delete_account.dart';
import 'package:wappa_app/features/profile/presentation/cubit/privacy_settings_cubit.dart';
import 'package:wappa_app/features/profile/presentation/cubit/privacy_settings_state.dart';

class ProfileAccountSettingsPage extends StatelessWidget {
  const ProfileAccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PrivacySettingsCubit>(
      create: (_) => sl<PrivacySettingsCubit>()..load(),
      child: const _AccountSettingsView(),
    );
  }
}

class _AccountSettingsView extends StatelessWidget {
  const _AccountSettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil & cuenta')),
      body: BlocConsumer<PrivacySettingsCubit, PrivacySettingsState>(
        listener: (context, state) {
          if (state.status == PrivacySettingsStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
          }
        },
        builder: (context, state) {
          final settings = state.settings ?? PrivacySettingsEntity.defaults;
          final isLoading =
              state.status == PrivacySettingsStatus.loading && state.settings == null;
          final isSaving = state.status == PrivacySettingsStatus.saving;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const _SectionHeader('Privacidad'),
              _AdaptiveSwitchTile(
                title: 'Favoritos privados',
                subtitle:
                    'Oculta tu lista de libros favoritos para otros usuarios.',
                value: settings.favoritesPrivate,
                enabled: !isLoading && !isSaving,
                onChanged: (value) => context
                    .read<PrivacySettingsCubit>()
                    .toggleFavoritesPrivate(value),
              ),
              _AdaptiveSwitchTile(
                title: 'Libros privados',
                subtitle:
                    'Oculta tus libros publicados del perfil público.',
                value: settings.booksPrivate,
                enabled: !isLoading && !isSaving,
                onChanged: (value) => context
                    .read<PrivacySettingsCubit>()
                    .toggleBooksPrivate(value),
              ),
              _AdaptiveSwitchTile(
                title: 'Seguidores privados',
                subtitle: 'Evita que otros vean quién te sigue.',
                value: settings.followersPrivate,
                enabled: !isLoading && !isSaving,
                onChanged: (value) => context
                    .read<PrivacySettingsCubit>()
                    .toggleFollowersPrivate(value),
              ),
              _AdaptiveSwitchTile(
                title: 'Seguidos privados',
                subtitle: 'Oculta a quién sigues dentro de la plataforma.',
                value: settings.followingPrivate,
                enabled: !isLoading && !isSaving,
                onChanged: (value) => context
                    .read<PrivacySettingsCubit>()
                    .toggleFollowingPrivate(value),
              ),
              if (isSaving)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 24),
              const _SectionHeader('Cuenta'),
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Cambiar contraseña'),
                subtitle: const Text('Disponible próximamente.'),
                onTap: () => _showUpcomingFeature(context),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Actualizar correo'),
                subtitle: const Text('Disponible próximamente.'),
                onTap: () => _showUpcomingFeature(context),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                title: const Text(
                  'Eliminar cuenta',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Esta acción es permanente y eliminará todo tu contenido.'),
                onTap: () => _showDeleteAccountDialog(context),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AdaptiveSwitchTile extends StatelessWidget {
  const _AdaptiveSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

void _showUpcomingFeature(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Funcionalidad disponible próximamente.')),
    );
}

void _showDeleteAccountDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
      title: const Text('¿Eliminar tu cuenta?'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acción es PERMANENTE y eliminará:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('• Todos tus libros y capítulos publicados'),
            Text('• Todos tus comentarios en cualquier libro'),
            Text('• Todos tus likes y favoritos'),
            Text('• Tus seguidores y seguidos'),
            Text('• Todos tus mensajes directos'),
            Text('• Todas tus notificaciones'),
            Text('• Tu perfil completo'),
            SizedBox(height: 16),
            Text(
              '⚠️ No podrás recuperar esta información después de eliminar tu cuenta.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _confirmDeleteAccount(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}

void _confirmDeleteAccount(BuildContext context) {
  final textController = TextEditingController();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmación final'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Para confirmar que deseas eliminar tu cuenta, escribe:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'ELIMINAR MI CUENTA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Escribe aquí',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (textController.text.trim() == 'ELIMINAR MI CUENTA') {
              Navigator.of(dialogContext).pop();
              _executeDeleteAccount(context);
            } else {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('El texto no coincide. Por favor verifica.'),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Eliminar definitivamente'),
        ),
      ],
    ),
  );
}

void _executeDeleteAccount(BuildContext context) async {
  // Mostrar diálogo de progreso
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Eliminando tu cuenta...'),
          Text('Por favor espera', style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );

  try {
    // Ejecutar la eliminación
    await sl<DeleteAccountUseCase>().call();

    // Cerrar diálogo de progreso
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // La sesión ya fue cerrada en el deleteAccount, 
    // el AuthBloc detectará automáticamente y navegará al LoginPage
    // Solo mostramos un mensaje de éxito temporal
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tu cuenta ha sido eliminada correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    // Cerrar diálogo de progreso
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Mostrar error
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al eliminar la cuenta: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
