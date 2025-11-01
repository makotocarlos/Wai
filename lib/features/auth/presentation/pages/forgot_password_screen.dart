import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

class ForgotPasswordScreen extends StatefulWidget {
	const ForgotPasswordScreen({super.key});

	static const String routeName = '/forgot-password';

	@override
	State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
	final _formKey = GlobalKey<FormState>();
	final _emailController = TextEditingController();

	@override
	void dispose() {
		_emailController.dispose();
		super.dispose();
	}

	void _submit() {
		if (!_formKey.currentState!.validate()) {
			return;
		}

		context.read<AuthBloc>().add(
					AuthSendPasswordResetRequested(
						_emailController.text.trim(),
					),
				);

		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(
				content: Text('Si el correo existe, te llegara un enlace de recuperacion.'),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Restablecer contrasena'),
			),
			body: SafeArea(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
					child: Form(
						key: _formKey,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text(
									'Ingresa tu correo y te enviaremos un enlace para restablecer la contrasena.',
									style: Theme.of(context).textTheme.bodyLarge,
								),
								const SizedBox(height: 24),
								TextFormField(
									controller: _emailController,
									keyboardType: TextInputType.emailAddress,
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
								const SizedBox(height: 24),
								ElevatedButton(
									onPressed: _submit,
									child: const Text('Enviar enlace'),
								),
							],
						),
					),
				),
			),
		);
	}
}
