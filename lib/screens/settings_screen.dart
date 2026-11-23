import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_provider.dart';
import '../services/import_export.dart';
import '../services/settings_service.dart';
import '../store/todo_store.dart';

/// Settings page: theme, first day of week, import/export, clear completed,
/// and about.
class SettingsScreen extends StatefulWidget {
  final TodoStore store;
  final SettingsService settings;
  final LanguageProvider language;

  const SettingsScreen({
    super.key,
    required this.store,
    required this.settings,
    required this.language,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _io = ImportExportService();
  String? _status;

  Future<void> _export() async {
    setState(() => _status = null);
    try {
      final ok = await _io.exportBackup();
      if (!mounted) return;
      setState(() => _status = ok
          ? AppStrings.tr('exportSaved')
          : AppStrings.tr('exportCancelled'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = AppStrings.tr('exportFailed', {'error': '$e'}));
    }
  }

  Future<void> _import() async {
    setState(() => _status = null);
    try {
      final result = await _io.importFromPicker();
      if (!mounted) return;
      if (result == null) {
        setState(() => _status = AppStrings.tr('importCancelled'));
        return;
      }
      await widget.store.refreshAll();
      final warnings = result.warnings.isEmpty
          ? ''
          : '\n${result.warnings.join('\n')}';
      final stepsSuffix = result.stepsImported > 0
          ? ' (${result.stepsImported} steps)'
          : '';
      setState(() => _status = AppStrings.tr('importDone', {
            'tasks': '${result.tasksImported}',
            'lists': '${result.listsCreated}',
            'steps': stepsSuffix,
          }) +
          warnings);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = AppStrings.tr('importFailed', {'error': '$e'}));
    }
  }

  Future<void> _clearCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.tr('clearCompletedTitle')),
        content: Text(AppStrings.tr('clearCompletedMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.tr('clear')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.clearCompleted();
      if (mounted) {
        setState(() => _status = AppStrings.tr('clearedCompleted'));
      }
    }
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final language = widget.language;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppStrings.tr('language')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('system'),
            child: Row(
              children: [
                Expanded(child: Text(AppStrings.tr('systemDefault'))),
                if (language.isSystem)
                  const Icon(Icons.check, color: Color(0xFF0078D4)),
              ],
            ),
          ),
          for (final code in AppStrings.supportedCodes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(code),
              child: Row(
                children: [
                  Expanded(
                      child: Text(AppStrings.nativeNames[code] ?? code)),
                  if (!language.isSystem && language.code == code)
                    const Icon(Icons.check, color: Color(0xFF0078D4)),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await language.setLanguage(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.tr('settings'))),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _section(context, AppStrings.tr('appearance')),
              RadioListTile<ThemeMode>(
                title: Text(AppStrings.tr('systemDefault')),
                value: ThemeMode.system,
                groupValue: settings.themeMode,
                onChanged: (v) => settings.setThemeMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: Text(AppStrings.tr('light')),
                value: ThemeMode.light,
                groupValue: settings.themeMode,
                onChanged: (v) => settings.setThemeMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: Text(AppStrings.tr('dark')),
                value: ThemeMode.dark,
                groupValue: settings.themeMode,
                onChanged: (v) => settings.setThemeMode(v!),
              ),
              _section(context, AppStrings.tr('language')),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(AppStrings.tr('language')),
                subtitle: Text(widget.language.isSystem
                    ? AppStrings.tr('systemDefault')
                    : (AppStrings.nativeNames[widget.language.code] ??
                        widget.language.code)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context),
              ),
              _section(context, AppStrings.tr('calendar')),
              ListTile(
                title: Text(AppStrings.tr('firstDayOfWeek')),
                trailing: DropdownButton<int>(
                  value: settings.firstDayOfWeek,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: 1, child: Text(AppStrings.tr('monday'))),
                    DropdownMenuItem(value: 0, child: Text(AppStrings.tr('sunday'))),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.setFirstDayOfWeek(v);
                  },
                ),
              ),
              _section(context, AppStrings.tr('data')),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: Text(AppStrings.tr('exportBackup')),
                subtitle: Text(AppStrings.tr('exportBackupSub')),
                onTap: _export,
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(AppStrings.tr('import')),
                subtitle: Text(AppStrings.tr('importSub')),
                onTap: _import,
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(AppStrings.tr('clearCompleted')),
                onTap: _clearCompleted,
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    _status!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              _section(context, AppStrings.tr('about')),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(AppStrings.tr('appTitle')),
                subtitle: Text(AppStrings.tr('aboutText')),
              ),
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: Text(AppStrings.tr('sourceCode')),
                subtitle: const Text(
                    'github.com/Anathleticbicyclist/open-todo'),
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
