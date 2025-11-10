import '../entities/privacy_settings_entity.dart';
import '../repositories/profile_repository.dart';

class GetPrivacySettingsUseCase {
  const GetPrivacySettingsUseCase(this._repository);

  final ProfileRepository _repository;

  Future<PrivacySettingsEntity> call() {
    return _repository.fetchPrivacySettings();
  }
}
