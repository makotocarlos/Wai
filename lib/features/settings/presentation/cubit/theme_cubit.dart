import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_theme_mode.dart';
import '../../domain/usecases/load_theme_mode.dart';
import '../../domain/usecases/update_theme_mode.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({required LoadThemeMode loadThemeMode, required UpdateThemeMode updateThemeMode})
      : _loadThemeMode = loadThemeMode,
        _updateThemeMode = updateThemeMode,
        super(ThemeMode.dark);

  final LoadThemeMode _loadThemeMode;
  final UpdateThemeMode _updateThemeMode;

  Future<void> loadTheme() async {
    final mode = await _loadThemeMode();
    emit(_mapToFlutterMode(mode));
  }

  Future<void> toggleDarkMode(bool enabled) async {
    final newMode = enabled ? AppThemeMode.dark : AppThemeMode.light;
    await _updateThemeMode(newMode);
    emit(_mapToFlutterMode(newMode));
  }

  ThemeMode _mapToFlutterMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
    };
  }
}
