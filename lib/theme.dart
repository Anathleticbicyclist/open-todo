import 'package:flutter/material.dart';

/// Microsoft To Do visual language: clean light background, Microsoft blue
/// accent (#0078D4), subtle dividers, rounded controls.
///
/// Exact To Do color tokens:
/// - primary blue #0078D4, page white, sidebar #F3F2F1
/// - primary text #323130, secondary text #605E5C
/// - completed-task text #A19F9D, dividers #EDEBE9, hover #F3F2F1
class AppTheme {
  static const Color msBlue = Color(0xFF0078D4);
  static const Color msBlueDark = Color(0xFF106EBE);
  static const Color msBlueLight = Color(0xFFDEECF9);
  static const Color sidebarLight = Color(0xFFF3F2F1);
  static const Color sidebarDark = Color(0xFF1B1A19);
  static const Color dividerLight = Color(0xFFEDEBE9);
  static const Color textPrimary = Color(0xFF323130);
  static const Color textSecondaryLight = Color(0xFF605E5C);
  static const Color textCompleted = Color(0xFFA19F9D);
  static const Color hoverLight = Color(0xFFF3F2F1);
  static const Color danger = Color(0xFFA4262C);

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: msBlue,
      secondary: msBlue,
      surface: Colors.white,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondaryLight),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: dividerLight,
      listTileTheme: const ListTileThemeData(
        iconColor: textPrimary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return msBlue;
          return Colors.transparent;
        }),
        shape: const CircleBorder(),
        side: const BorderSide(color: Color(0xFF8A8886), width: 1.5),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: msBlue,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: msBlue),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF4CC2FF),
      secondary: Color(0xFF4CC2FF),
      surface: Color(0xFF201F1E),
      error: Color(0xFFF1707B),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF201F1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF201F1E),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: const Color(0xFF3B3A39),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF4CC2FF);
          }
          return Colors.transparent;
        }),
        shape: const CircleBorder(),
        side: const BorderSide(color: Color(0xFF8A8886), width: 1.5),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF4CC2FF),
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF3B3A39)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF4CC2FF)),
        ),
      ),
    );
  }

  /// Parses a '#RRGGBB' hex colour string into a [Color].
  static Color hexToColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  /// Formats a [Color] back to '#RRGGBB'.
  static String colorToHex(Color color) {
    final v = color.value & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
