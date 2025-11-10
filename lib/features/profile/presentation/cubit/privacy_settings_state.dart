import 'package:equatable/equatable.dart';

import '../../domain/entities/privacy_settings_entity.dart';

enum PrivacySettingsStatus { initial, loading, loaded, saving, error }

class PrivacySettingsState extends Equatable {
  const PrivacySettingsState({
    this.status = PrivacySettingsStatus.initial,
    this.settings,
    this.errorMessage,
  });

  final PrivacySettingsStatus status;
  final PrivacySettingsEntity? settings;
  final String? errorMessage;

  bool get canToggle =>
      status == PrivacySettingsStatus.loaded || status == PrivacySettingsStatus.error;

  PrivacySettingsState copyWith({
    PrivacySettingsStatus? status,
    PrivacySettingsEntity? settings,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrivacySettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, settings, errorMessage];
}
