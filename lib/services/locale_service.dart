import 'package:flutter/material.dart';

/// Service for managing app locale/language
class LocaleService extends ChangeNotifier {
  Locale _locale = const Locale('en'); // Default to English

  Locale get locale => _locale;

  /// Change the app locale
  void changeLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
  }

  /// Change locale by language code
  void changeLanguage(String languageCode) {
    changeLocale(Locale(languageCode));
  }

  /// Check if current locale is Polish
  bool get isPolish => _locale.languageCode == 'pl';

  /// Check if current locale is English
  bool get isEnglish => _locale.languageCode == 'en';

  /// Get list of supported locales
  static List<Locale> get supportedLocales => const [
        Locale('pl'),
        Locale('en'),
      ];
}
