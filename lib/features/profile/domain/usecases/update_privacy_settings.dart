import '../entities/privacy_settings_entity.dart';
import '../repositories/profile_repository.dart';

class UpdatePrivacySettingsUseCase {
  const UpdatePrivacySettingsUseCase(this._repository);

  final ProfileRepository _repository;

  Future<PrivacySettingsEntity> call(PrivacySettingsEntity settings) {
    return _repository.updatePrivacySettings(settings);
  }
}
