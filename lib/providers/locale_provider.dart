import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

class LocaleProvider with ChangeNotifier {
  static const String prefKey = 'app_language';

  String _language = AppStrings.defaultLanguage;
  String get language => _language;
  bool get isMalay => _language == AppStrings.ms;

  LocaleProvider() {
    _load();
  }

  /// Reads the saved language (Malay when nothing was saved). Usable without a provider instance.
  static Future<String> savedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefKey) ?? AppStrings.defaultLanguage;
    } catch (_) {
      return AppStrings.defaultLanguage;
    }
  }

  Future<void> _load() async {
    _language = await savedLanguage();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, lang);
  }

  String t(String key, [Map<String, String>? params]) =>
      AppStrings.get(_language, key, params);

  String prayer(String englishName) => AppStrings.prayer(_language, englishName);
}
