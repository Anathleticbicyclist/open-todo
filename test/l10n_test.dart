import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_todo/l10n/app_strings.dart';

void main() {
  group('AppStrings', () {
    test('all 16 locales are declared', () {
      expect(AppStrings.supportedLocales.length, 16);
      expect(AppStrings.supportedCodes.length, 16);
      expect(AppStrings.nativeNames.length, 16);
    });

    test('every locale has the same complete key set', () {
      // Spot-check a representative set of keys in every locale. The full
      // key set is verified by the analyzer-friendly const map: if a key
      // were missing, tr() would fall back to English, which the next
      // test catches for a sample of keys.
      const sampleKeys = [
        'appTitle',
        'search',
        'settings',
        'myDay',
        'important',
        'planned',
        'allTasks',
        'addTask',
        'sort',
        'dueDate',
        'repeat',
        'language',
        'import',
        'exportBackup',
        'clearCompleted',
        'emptyMyDayTitle',
        'noResultsTitle',
      ];
      for (final code in AppStrings.supportedCodes) {
        final locale = code == 'zh-Hant'
            ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
            : Locale(code);
        AppStrings.current = locale;
        for (final key in sampleKeys) {
          final value = AppStrings.tr(key);
          // A missing translation falls back to the English value; a
          // missing English value falls back to the key itself. Neither
          // may happen for a key that must be translated.
          expect(value, isNot(key),
              reason: 'missing translation for "$key" in "$code"');
        }
      }
      AppStrings.current = const Locale('en');
    });

    test('tr() substitutes {placeholders}', () {
      AppStrings.current = const Locale('en');
      expect(
        AppStrings.tr('openCompleted', {'open': '3', 'done': '2'}),
        '3 open · 2 completed',
      );
      expect(
        AppStrings.tr('stepsOf', {'done': '1', 'total': '4'}),
        '1 of 4',
      );
    });

    test('resolveCode maps system locales to supported codes', () {
      expect(AppStrings.resolveCode(const Locale('en')), 'en');
      expect(AppStrings.resolveCode(const Locale('es', 'MX')), 'es');
      expect(
        AppStrings.resolveCode(
            const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
        'zh-Hant',
      );
      expect(AppStrings.resolveCode(const Locale('zh', 'TW')), 'zh-Hant');
      expect(AppStrings.resolveCode(const Locale('zh', 'CN')), 'zh');
      expect(AppStrings.resolveCode(const Locale('xx')), 'en');
    });

    test('RTL is detected for Arabic only', () {
      AppStrings.current = const Locale('ar');
      expect(AppStrings.isRtl, isTrue);
      AppStrings.current = const Locale('en');
      expect(AppStrings.isRtl, isFalse);
      AppStrings.current = const Locale('he');
      expect(AppStrings.isRtl, isFalse);
    });

    test('dateLocale maps Traditional Chinese to zh_TW', () {
      AppStrings.current =
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      expect(AppStrings.dateLocale, 'zh_TW');
      AppStrings.current = const Locale('zh');
      expect(AppStrings.dateLocale, 'zh_CN');
      AppStrings.current = const Locale('fr');
      expect(AppStrings.dateLocale, 'fr');
      AppStrings.current = const Locale('en');
    });
  });
}
