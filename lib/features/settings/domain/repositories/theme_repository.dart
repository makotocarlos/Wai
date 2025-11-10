import '../entities/app_theme_mode.dart';

abstract class ThemeRepository {
  Future<AppThemeMode> loadThemeMode();
  Future<void> updateThemeMode(AppThemeMode mode);
}
