import 'package:flutter/material.dart';

import 'l10n/app_strings.dart';
import 'l10n/language_provider.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'store/todo_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService();
  await settings.load();
  final language = LanguageProvider();
  await language.load();
  final store = TodoStore();
  await store.init();
  runApp(OpenTodoApp(
    settings: settings,
    language: language,
    store: store,
  ));
}

class OpenTodoApp extends StatelessWidget {
  final SettingsService settings;
  final LanguageProvider language;
  final TodoStore store;

  const OpenTodoApp({
    super.key,
    required this.settings,
    required this.language,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([settings, language, store]),
      builder: (context, _) {
        return MaterialApp(
          title: AppStrings.tr('appTitle'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: language.locale,
          supportedLocales: AppStrings.supportedLocales,
          // MaterialApp derives textDirection from the locale, so Arabic
          // (ar) automatically renders right-to-left.
          home: HomeScreen(store: store, settings: settings, language: language),
        );
      },
    );
  }
}
