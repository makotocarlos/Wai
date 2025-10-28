import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/widgets/CustomTextField.dart';
import '../../../../shared/widgets/PrimaryButton.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/usecases/check_username_exists.dart';

class RegisterPage extends StatefulWidget {
  final CheckUsernameExists checkUsernameExists;

  const RegisterPage({super.key, required this.checkUsernameExists});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: Colors.grey[900],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cuenta creada con éxito')),
            );
            Navigator.pop(context); // Regresa al login
          } else if (state is AuthFailure) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: nameCtrl,
                    hint: 'Nombre de usuario',
                    focusedBorderColor: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: emailCtrl,
                    hint: 'Correo electrónico',
                    keyboardType: TextInputType.emailAddress,
                    focusedBorderColor: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: passCtrl,
                    hint: 'Contraseña',
                    obscure: !_showPassword,
                    focusedBorderColor: Colors.green,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: confirmPassCtrl,
                    hint: 'Confirmar contraseña',
                    obscure: !_showConfirmPassword,
                    focusedBorderColor: Colors.green,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() => _showConfirmPassword = !_showConfirmPassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : PrimaryButton(
                          text: 'Registrar',
                          onPressed: () async {
                            await _submit(authBloc);
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthBloc bloc) async {
    setState(() {
      _errorMessage = null;
    });

    final username = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    // Validaciones locales
    if (username.isEmpty || email.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = 'Por favor completa todos los campos');
      return;
    }

    if (pass != confirmPass) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    if (!_isPasswordValid(pass)) {
      setState(() => _errorMessage =
          'La contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula y un número');
      return;
    }

    setState(() => _isLoading = true);

    // Validar si el nombre de usuario existe
    final exists = await widget.checkUsernameExists.call(username);
    if (exists) {
      setState(() {
        _errorMessage = 'El nombre de usuario ya está en uso';
        _isLoading = false;
      });
      return;
    }

    // Disparamos el evento al Bloc correctamente con parámetros nombrados
    bloc.add(SignUpWithEmailEvent(
      email: email,
      password: pass,
      username: username,
    ));
  }

  bool _isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(password);
  }
}
