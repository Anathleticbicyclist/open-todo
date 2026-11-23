import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Holds the current app language and persists the choice.
///
/// Fallback chain: saved language -> system locale (if supported) -> English.
/// Changing the language applies immediately — no restart needed — because
/// [AppStrings.current] is updated and listeners rebuild the app.
class LanguageProvider extends ChangeNotifier {
  static const String _keyLanguage = 'language_code';

  /// 'system' or one of [AppStrings.supportedCodes].
  String _code = 'system';

  String get code => _code;

  bool get isSystem => _code == 'system';

  Locale get locale {
    if (_code != 'system') return _localeFromCode(_code);
    final sys = ui.PlatformDispatcher.instance.locale;
    return _localeFromCode(AppStrings.resolveCode(sys));
  }

  static Locale _localeFromCode(String code) {
    if (code == 'zh-Hant') {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    }
    return Locale(code);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyLanguage);
    if (saved != null &&
        (saved == 'system' || AppStrings.supportedCodes.contains(saved))) {
      _code = saved;
    }
    AppStrings.current = locale;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code != 'system' && !AppStrings.supportedCodes.contains(code)) {
      return;
    }
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
    AppStrings.current = locale;
    notifyListeners();
  }
}
