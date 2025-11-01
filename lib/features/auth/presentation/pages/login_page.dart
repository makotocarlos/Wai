import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginPage extends StatefulWidget {
	const LoginPage({super.key});

	static const String routeName = '/login';

	@override
	State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
	final _formKey = GlobalKey<FormState>();
	final _emailController = TextEditingController();
	final _passwordController = TextEditingController();
	bool _obscurePassword = true;

	@override
	void dispose() {
		_emailController.dispose();
		_passwordController.dispose();
		super.dispose();
	}

	void _submit() {
		if (!_formKey.currentState!.validate()) {
			return;
		}

		context.read<AuthBloc>().add(
					AuthSignInRequested(
						email: _emailController.text.trim(),
						password: _passwordController.text,
					),
				);
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final isLoading = context.watch<AuthBloc>().state.status == AuthStatus.loading;

		return Scaffold(
			body: SafeArea(
				child: Center(
					child: SingleChildScrollView(
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 420),
							child: Form(
								key: _formKey,
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Center(
											child: Image.asset(
												'assets/logo.png',
												height: 120,
											),
										),
										const SizedBox(height: 16),
										Text(
											'WAI',
											style: theme.textTheme.displaySmall?.copyWith(
												color: theme.colorScheme.primary,
												fontWeight: FontWeight.bold,
											),
											textAlign: TextAlign.center,
										),
										const SizedBox(height: 8),
										Text(
											'Inicia sesion para continuar escribiendo',
											style: theme.textTheme.bodyLarge,
											textAlign: TextAlign.center,
										),
										const SizedBox(height: 32),
										TextFormField(
											controller: _emailController,
											keyboardType: TextInputType.emailAddress,
											textInputAction: TextInputAction.next,
											decoration: const InputDecoration(
												labelText: 'Correo electronico',
												prefixIcon: Icon(Icons.mail_outline),
											),
											validator: (value) {
												if (value == null || value.trim().isEmpty) {
													return 'Ingresa tu correo';
												}
												if (!value.contains('@')) {
													return 'Correo invalido';
												}
												return null;
											},
										),
										const SizedBox(height: 16),
										TextFormField(
											controller: _passwordController,
											obscureText: _obscurePassword,
											textInputAction: TextInputAction.done,
											onFieldSubmitted: (_) => _submit(),
											decoration: InputDecoration(
												labelText: 'Contrasena',
												prefixIcon: const Icon(Icons.lock_outline),
												suffixIcon: IconButton(
													onPressed: () => setState(() {
														_obscurePassword = !_obscurePassword;
													}),
													icon: Icon(
														_obscurePassword ? Icons.visibility : Icons.visibility_off,
													),
												),
											),
											validator: (value) {
												if (value == null || value.isEmpty) {
													return 'Ingresa tu contrasena';
												}
												if (value.length < 6) {
													return 'La contrasena debe tener al menos 6 caracteres';
												}
												return null;
											},
										),
										const SizedBox(height: 12),
										Align(
											alignment: Alignment.centerRight,
											child: TextButton(
												onPressed: () => Navigator.of(context).pushNamed(
													ForgotPasswordScreen.routeName,
												),
												child: const Text('Olvidaste tu contrasena?'),
											),
										),
										const SizedBox(height: 24),
										ElevatedButton(
											onPressed: isLoading ? null : _submit,
											child: isLoading
												? const SizedBox(
														height: 20,
														width: 20,
														child: CircularProgressIndicator(strokeWidth: 2),
													)
												: const Text('Iniciar sesion'),
										),
										const SizedBox(height: 16),
										Row(
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												const Text('No tienes cuenta?'),
												TextButton(
													onPressed: () => Navigator.of(context).pushNamed(
														RegisterScreen.routeName,
													),
													child: const Text('Registrate'),
												),
											],
										),
									],
								),
							),
						),
					),
				),
			),
		);
	}
}
