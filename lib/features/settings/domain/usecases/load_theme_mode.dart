import '../entities/app_theme_mode.dart';
import '../repositories/theme_repository.dart';

class LoadThemeMode {
  const LoadThemeMode(this._repository);

  final ThemeRepository _repository;

  Future<AppThemeMode> call() {
    return _repository.loadThemeMode();
  }
}
