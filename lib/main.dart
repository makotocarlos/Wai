import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/di/injection.dart';
import 'core/supabase/supabase_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/forgot_password_screen.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'features/settings/presentation/cubit/theme_cubit.dart';
import 'shared/theme/app_theme.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    if (kDebugMode) {
      debugPrint('No se pudo cargar .env, continuamos con dart-define: $error');
    }
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  final client = await SupabaseService.initialize();

  if (client == null) {
    runApp(const SupabaseErrorApp());
    return;
  }

  await initInjection(client);

  runApp(const WaiRoot());
}

class WaiRoot extends StatelessWidget {
  const WaiRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const AuthInitialize()),
        ),
        BlocProvider<ThemeCubit>(
          create: (_) => sl<ThemeCubit>()..loadTheme(),
        ),
      ],
      child: const WaiApp(),
    );
  }
}

class WaiApp extends StatelessWidget {
  const WaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'WAI',
          theme: AppTheme.lightGreen,
          darkTheme: AppTheme.darkGreen,
          themeMode: themeMode,
          routes: {
            RegisterScreen.routeName: (_) => const RegisterScreen(),
            ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
            HomeScreen.routeName: (_) => const HomeScreen(),
          },
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          switch (state.status) {
            case AuthStatus.initial:
            case AuthStatus.loading:
              return const _AuthLoading();
            case AuthStatus.authenticated:
              return const HomeScreen();
            case AuthStatus.unauthenticated:
              return const LoginPage();
          }
        },
      ),
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          height: 48,
          width: 48,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class SupabaseErrorApp extends StatelessWidget {
  const SupabaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkGreen,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Color(0xFF00FF88),
                ),
                SizedBox(height: 16),
                Text(
                  'Faltan las variables de Supabase',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Ejecuta la app con --dart-define=SUPABASE_URL=... y --dart-define=SUPABASE_ANON_KEY=... para inicializar la sesión.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
