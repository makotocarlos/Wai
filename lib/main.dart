import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/domain/usecases/check_username_exists.dart';
import 'features/books/presentation/cubit/book_list_cubit.dart';
import 'shared/widgets/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase
  await Firebase.initializeApp();

  // Inyección de dependencias
  await initDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<BookListCubit>(
          create: (_) => sl<BookListCubit>()..start(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Wappa App',
        theme: ThemeData.dark().copyWith(
          primaryColor: Colors.green,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        // Pantalla inicial
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
    listenWhen: (previous, current) =>
      (current is Authenticated && previous is! Authenticated) ||
      current is AuthFailure,
      listener: (context, state) {
        if (state is Authenticated) {
          final lines = <String>[];
          final email = state.user.email;
          lines.add(
            email != null && email.isNotEmpty
                ? 'Bienvenido $email'
                : 'Bienvenido',
          );
          final infoMessage = state.infoMessage;
          if (infoMessage != null && infoMessage.isNotEmpty) {
            lines.add(infoMessage);
          }
          final message = lines.join('\n');
          if (message.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading || state is AuthInitial) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is Authenticated) {
            return const MainLayout();
          }
          return LoginPage(
            checkUsernameExists: sl<CheckUsernameExists>(),
          );
        },
      ),
    );
  }
}
