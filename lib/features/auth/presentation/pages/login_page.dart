// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wappa_app/shared/widgets/SubtitleText.dart';
import '../../../../shared/widgets/AppLogo.dart';
import '../../../../shared/widgets/CustomTextField.dart';
import '../../../../shared/widgets/OutlinedButtonCustom.dart';
import '../../../../shared/widgets/PrimaryButton.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../../domain/usecases/check_username_exists.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.checkUsernameExists});

  final CheckUsernameExists checkUsernameExists;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _LoginView(checkUsernameExists: checkUsernameExists),
      ),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.checkUsernameExists});

  final CheckUsernameExists checkUsernameExists;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(),
          // Logo y subtítulo
          Stack(
            alignment: Alignment.topCenter,
            children: [
              const AppLogo(size: 150),
              Transform.translate(
                offset: const Offset(0, 120),
                child: const SubtitleText('Aplicación narrativa W-AI'),
              ),
            ],
          ),
          const SizedBox(height: 80),

          // Botón Google
          OutlinedButtonCustom(
            text: 'Regístrate con Google',
            icon: Icons.g_mobiledata,
            onPressed: () => bloc.add(SignInWithGoogleEvent()),
          ),
          const SizedBox(height: 18),

          // Botón registro con correo
          PrimaryButton(
            text: 'Regístrate con un correo electrónico',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegisterPage(
                    checkUsernameExists: widget.checkUsernameExists,
                  ),
                ),
              );
            },
          ),

          const Spacer(),

          // Login
          TextButton(
            onPressed: () => _showEmailForm(context, bloc),
            child: const Text(
              'Ya tengo una cuenta',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showEmailForm(BuildContext context, AuthBloc bloc) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? _errorMessage;
        bool _showPassword = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is Authenticated) {
                      Navigator.pop(ctx);
                    } else if (state is AuthFailure) {
                      setState(() {
                        _errorMessage = state.message;
                      });
                    }
                  },
                  builder: (context, state) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTextField(
                            controller: emailCtrl,
                            hint: 'Correo',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: passCtrl,
                            hint: 'Contraseña',
                            obscure: !_showPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          PrimaryButton(
                            text:
                                state is AuthLoading ? 'Cargando...' : 'Entrar',
                            onPressed: () {
                              final email = emailCtrl.text.trim();
                              final pass = passCtrl.text.trim();
                              bloc.add(SignInWithEmailEvent(email, pass));
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButtonCustom(
                            text: '¿Olvidaste tu contraseña?',
                            icon: Icons.lock_open,
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
