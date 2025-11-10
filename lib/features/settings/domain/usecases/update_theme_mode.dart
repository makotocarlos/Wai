import '../entities/app_theme_mode.dart';
import '../repositories/theme_repository.dart';

class UpdateThemeMode {
  const UpdateThemeMode(this._repository);

  final ThemeRepository _repository;

  Future<void> call(AppThemeMode mode) {
    return _repository.updateThemeMode(mode);
  }
}
