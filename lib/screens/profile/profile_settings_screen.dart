import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../features/auth/domain/usecases/check_username_exists.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.black,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  checkUsernameExists: sl<CheckUsernameExists>(),
                ),
              ),
              (route) => false,
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return ListView(
            children: [
              const ListTile(
                title: Text('Perfil & cuenta'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const ListTile(
                title: Text('Notificaciones'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const ListTile(
                title: Text('Preferencias de lectura'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const ListTile(
                title: Text('Modo oscuro'),
                subtitle: Text('Automático'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const Divider(),
              const ListTile(
                title: Text('Privacidad & seguridad'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const ListTile(
                title: Text('Suscripción Premium'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const ListTile(
                title: Text('Idioma de la historia'),
                subtitle: Text('Español'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
              const Divider(),
              ListTile(
                title: const Text('Cerrar sesión',
                    style: TextStyle(color: Colors.red)),
                leading: const Icon(Icons.logout, color: Colors.red),
                trailing: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: isLoading
                    ? null
                    : () {
                        context.read<AuthBloc>().add(SignOutEvent());
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
