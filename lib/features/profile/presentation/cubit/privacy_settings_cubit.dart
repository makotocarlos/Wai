import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/privacy_settings_entity.dart';
import '../../domain/usecases/get_privacy_settings.dart';
import '../../domain/usecases/update_privacy_settings.dart';
import 'privacy_settings_state.dart';

class PrivacySettingsCubit extends Cubit<PrivacySettingsState> {
  PrivacySettingsCubit({
    required GetPrivacySettingsUseCase getPrivacySettings,
    required UpdatePrivacySettingsUseCase updatePrivacySettings,
  })  : _getPrivacySettings = getPrivacySettings,
        _updatePrivacySettings = updatePrivacySettings,
        super(const PrivacySettingsState());

  final GetPrivacySettingsUseCase _getPrivacySettings;
  final UpdatePrivacySettingsUseCase _updatePrivacySettings;

  Future<void> load() async {
    emit(state.copyWith(status: PrivacySettingsStatus.loading, clearError: true));
    try {
      final settings = await _getPrivacySettings();
      emit(
        state.copyWith(
          status: PrivacySettingsStatus.loaded,
          settings: settings,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: PrivacySettingsStatus.error,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> toggleFavoritesPrivate(bool value) async {
    await _persist((settings) => settings.copyWith(favoritesPrivate: value));
  }

  Future<void> toggleBooksPrivate(bool value) async {
    await _persist((settings) => settings.copyWith(booksPrivate: value));
  }

  Future<void> toggleFollowersPrivate(bool value) async {
    await _persist((settings) => settings.copyWith(followersPrivate: value));
  }

  Future<void> toggleFollowingPrivate(bool value) async {
    await _persist((settings) => settings.copyWith(followingPrivate: value));
  }

  Future<void> _persist(
    PrivacySettingsEntity Function(PrivacySettingsEntity current) transformer,
  ) async {
    final currentSettings = state.settings ?? PrivacySettingsEntity.defaults;
    final previousSettings = currentSettings;
    final updatedSettings = transformer(currentSettings);

    emit(
      state.copyWith(
        status: PrivacySettingsStatus.saving,
        settings: updatedSettings,
        clearError: true,
      ),
    );

    try {
      final saved = await _updatePrivacySettings(updatedSettings);
      emit(
        state.copyWith(
          status: PrivacySettingsStatus.loaded,
          settings: saved,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: PrivacySettingsStatus.error,
          errorMessage: error.toString(),
          settings: previousSettings,
        ),
      );
      emit(
        state.copyWith(
          status: PrivacySettingsStatus.loaded,
        ),
      );
    }
  }
}
