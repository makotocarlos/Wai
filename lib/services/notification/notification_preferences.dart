import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const _promptShownKey = 'notifications_prompt_shown';
  static const _pushEnabledKey = 'notifications_push_enabled';

  const NotificationPreferences._();

  static Future<bool> isPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptShownKey) ?? false;
  }

  static Future<void> setPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownKey, true);
  }

  static Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushEnabledKey) ?? false;
  }

  static Future<void> setPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, enabled);
  }
}
