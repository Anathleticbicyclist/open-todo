import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user settings (theme, first day of week) with shared_preferences.
class SettingsService extends ChangeNotifier {
  static const String _keyTheme = 'theme_mode';
  static const String _keyFirstDay = 'first_day_of_week';

  // Default to light: the system dark mode used to wash the UI out on
  // some phones (forced darkening), so light is the safe first-run look.
  // The user can still pick System or Dark in Settings.
  ThemeMode _themeMode = ThemeMode.light;
  int _firstDayOfWeek = 1; // 1 = Monday (ISO), 0 = Sunday

  ThemeMode get themeMode => _themeMode;
  int get firstDayOfWeek => _firstDayOfWeek;

  bool get weekStartsMonday => _firstDayOfWeek == 1;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_keyTheme);
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (theme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      // Nothing saved yet: light, not system.
      _themeMode = ThemeMode.light;
    }
    _firstDayOfWeek = prefs.getInt(_keyFirstDay) ?? 1;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyTheme,
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
    notifyListeners();
  }

  Future<void> setFirstDayOfWeek(int day) async {
    _firstDayOfWeek = day;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFirstDay, day);
    notifyListeners();
  }
}
