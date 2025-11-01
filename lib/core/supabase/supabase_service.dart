import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://leupcmmvwqtgbisnrhph.supabase.co',
);
const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxldXBjbW12d3F0Z2Jpc25yaHBoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NjkzNzYsImV4cCI6MjA3NzI0NTM3Nn0.Be3hXNG9bc_df8rO8BDN_YdzzxfIfh8cYycTfWlFKAI',
);

/// Handles Supabase initialization and exposes the shared [SupabaseClient].
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? _client;

  /// Returns `true` when both Supabase url and anon key were provided via
  /// `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`.
  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  /// Provides the initialized client if available.
  static SupabaseClient? get client => _client;

  /// Initializes Supabase when configuration is available.
  static Future<SupabaseClient?> initialize() async {
    if (_client != null) {
      return _client;
    }

    if (!isConfigured) {
      debugPrint(
        '[Supabase] Variables de entorno no encontradas. Ejecuta la app con '
        '--dart-define=SUPABASE_URL=... y --dart-define=SUPABASE_ANON_KEY=...',
      );
      return null;
    }

    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      _client = Supabase.instance.client;
      debugPrint('[Supabase] Inicializado correctamente con Realtime habilitado.');
    } catch (error, stackTrace) {
      debugPrint('[Supabase] Error al inicializar: $error');
      debugPrint('$stackTrace');
      _client = null;
    }

    return _client;
  }
}
