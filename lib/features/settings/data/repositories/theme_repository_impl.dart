import '../../domain/entities/app_theme_mode.dart';
import '../../domain/repositories/theme_repository.dart';
import '../datasources/theme_local_data_source.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._localDataSource);

  final ThemeLocalDataSource _localDataSource;

  @override
  Future<AppThemeMode> loadThemeMode() async {
    final storedValue = await _localDataSource.loadThemeMode();

    return switch (storedValue) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.dark,
    };
  }

  @override
  Future<void> updateThemeMode(AppThemeMode mode) {
    final storedValue = switch (mode) {
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
    };

    return _localDataSource.saveThemeMode(storedValue);
  }
}
