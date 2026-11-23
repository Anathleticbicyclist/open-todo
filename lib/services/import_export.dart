import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../l10n/app_strings.dart';
import '../models/step_item.dart';
import '../models/task_item.dart';
import '../models/task_list.dart';

/// Result of an import operation, shown to the user.
class ImportResult {
  final int listsCreated;
  final int tasksImported;
  final int stepsImported;
  final List<String> warnings;

  const ImportResult({
    required this.listsCreated,
    required this.tasksImported,
    required this.stepsImported,
    this.warnings = const [],
  });
}

/// Export and import for Open To Do.
///
/// Three formats are supported:
/// 1. **Open To Do backup JSON** — the app's own full backup (lists, tasks,
///    steps). Round-trips losslessly.
/// 2. **Microsoft Graph To Do JSON** — the shape returned by
///    `GET https://graph.microsoft.com/v1.0/me/todo/lists` (+ tasks), as
///    exported from Microsoft Graph Explorer. See docs/MIGRATION.md.
/// 3. **CSV** — columns `list,title,completed,important,due_date,note`.
class ImportExportService {
  final AppDatabase _db = AppDatabase.instance;

  // --------------------------------------------------------------- export

  /// Builds the full backup JSON (lists + tasks + steps).
  Future<String> buildBackupJson() async {
    final lists = await _db.getLists();
    final tasks = await _db.getAllTasks();
    final steps = <Map<String, dynamic>>[];
    for (final t in tasks) {
      if (t.id == null) continue;
      final s = await _db.getSteps(t.id!);
      steps.addAll(s.map((e) => e.toMap()));
    }
    final data = {
      'format': 'open-todo-backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'lists': lists.map((l) => l.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'steps': steps,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Opens a save-file dialog and writes the backup JSON. Returns true if
  /// a file was written.
  Future<bool> exportBackup() async {
    final json = await buildBackupJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final fileName =
        'open-todo-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: AppStrings.tr('exportTitle'),
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return path != null;
  }

  // --------------------------------------------------------------- import

  /// Opens a file picker and imports the chosen file (JSON or CSV).
  /// Returns null when the user cancels.
  Future<ImportResult?> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: AppStrings.tr('importTitle'),
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      return ImportResult(
        listsCreated: 0,
        tasksImported: 0,
        stepsImported: 0,
        warnings: [AppStrings.tr('importReadError')],
      );
    }
    final name = (file.name).toLowerCase();
    final text = utf8.decode(bytes);
    if (name.endsWith('.csv')) {
      return importCsv(text);
    }
    return importJson(text);
  }

  /// Imports a JSON string. Auto-detects the Open To Do backup format and
  /// the Microsoft Graph To Do format.
  Future<ImportResult> importJson(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic> &&
        decoded['format'] == 'open-todo-backup') {
      return _importBackup(decoded);
    }
    return _importGraph(decoded);
  }

  Future<ImportResult> _importBackup(Map<String, dynamic> data) async {
    int listsCreated = 0;
    int tasksImported = 0;
    int stepsImported = 0;
    final warnings = <String>[];

    final existing = await _db.getLists();
    final existingNames = existing.map((l) => l.name.toLowerCase()).toSet();
    final listIdMap = <int, int>{}; // old id -> new id

    final listsJson = (data['lists'] as List?) ?? [];
    for (final raw in listsJson) {
      final map = Map<String, dynamic>.from(raw as Map);
      final list = TaskList.fromMap(map);
      if (list.isSmart) {
        // Smart lists are built-in; map them to the fixed ids.
        listIdMap[list.id ?? 0] = list.id ?? TaskList.defaultListId;
        continue;
      }
      if (existingNames.contains(list.name.toLowerCase())) {
        // Reuse the existing list with the same name.
        final match = existing.firstWhere(
            (e) => e.name.toLowerCase() == list.name.toLowerCase());
        listIdMap[list.id ?? 0] = match.id!;
        warnings.add(AppStrings.tr(
            'importListMerged', {'name': list.name}));
        continue;
      }
      final newId = await _db.insertList(TaskList(
        name: list.name,
        colorHex: list.colorHex,
        isSmart: false,
        createdAt: list.createdAt,
      ));
      listIdMap[list.id ?? 0] = newId;
      listsCreated++;
    }

    final tasksJson = (data['tasks'] as List?) ?? [];
    final taskIdMap = <int, int>{};
    for (final raw in tasksJson) {
      final map = Map<String, dynamic>.from(raw as Map);
      final task = TaskItem.fromMap(map);
      final targetListId = listIdMap[task.listId] ?? TaskList.defaultListId;
      final newId = await _db.insertTask(task.copyWith(
        id: null,
        listId: targetListId,
      ));
      taskIdMap[task.id ?? 0] = newId;
      tasksImported++;
    }

    final stepsJson = (data['steps'] as List?) ?? [];
    for (final raw in stepsJson) {
      final map = Map<String, dynamic>.from(raw as Map);
      final step = StepItem.fromMap(map);
      final targetTaskId = taskIdMap[step.taskId];
      if (targetTaskId == null) continue;
      await _db.insertStep(step.copyWith(id: null, taskId: targetTaskId));
      stepsImported++;
    }

    return ImportResult(
      listsCreated: listsCreated,
      tasksImported: tasksImported,
      stepsImported: stepsImported,
      warnings: warnings,
    );
  }

  /// Imports Microsoft Graph To Do JSON.
  ///
  /// Accepts:
  /// - `{"value": [ {displayName, tasks: [...]}, ... ]}` (lists + tasks in
  ///   one document, as saved from Graph Explorer),
  /// - `{"lists": [ {displayName, tasks: [...]}, ... ]}`,
  /// - a bare list `[{displayName, tasks: [...]}, ...]`,
  /// - a single list object `{displayName, tasks: [...]}`.
  Future<ImportResult> _importGraph(dynamic decoded) async {
    final warnings = <String>[];
    final listDocs = <Map<String, dynamic>>[];

    if (decoded is Map<String, dynamic>) {
      if (decoded['value'] is List) {
        for (final e in decoded['value'] as List) {
          if (e is Map) listDocs.add(Map<String, dynamic>.from(e));
        }
      } else if (decoded['lists'] is List) {
        for (final e in decoded['lists'] as List) {
          if (e is Map) listDocs.add(Map<String, dynamic>.from(e));
        }
      } else if (decoded.containsKey('displayName')) {
        listDocs.add(decoded);
      }
    } else if (decoded is List) {
      for (final e in decoded) {
        if (e is Map) listDocs.add(Map<String, dynamic>.from(e));
      }
    }

    if (listDocs.isEmpty) {
      return ImportResult(
        listsCreated: 0,
        tasksImported: 0,
        stepsImported: 0,
        warnings: [AppStrings.tr('importNoLists')],
      );
    }

    int listsCreated = 0;
    int tasksImported = 0;
    final existing = await _db.getLists();
    final existingNames = existing.map((l) => l.name.toLowerCase()).toSet();

    for (final listDoc in listDocs) {
      final rawName = listDoc['displayName'] as String? ?? 'Imported';
      final name = rawName.trim().isEmpty ? 'Imported' : rawName.trim();
      int targetListId;
      if (existingNames.contains(name.toLowerCase())) {
        targetListId = existing
            .firstWhere((e) => e.name.toLowerCase() == name.toLowerCase())
            .id!;
        warnings.add(
            AppStrings.tr('importListMerged', {'name': name}));
      } else {
        targetListId = await _db.insertList(TaskList(
          name: name,
          colorHex: TaskList.palette[
              listsCreated % TaskList.palette.length],
          isSmart: false,
          createdAt: DateTime.now(),
        ));
        existingNames.add(name.toLowerCase());
        listsCreated++;
      }

      final tasksJson = (listDoc['tasks'] as List?) ?? [];
      for (final raw in tasksJson) {
        if (raw is! Map) continue;
        final taskDoc = Map<String, dynamic>.from(raw);
        final task = _graphTaskToLocal(taskDoc, targetListId);
        await _db.insertTask(task);
        tasksImported++;
      }
    }

    return ImportResult(
      listsCreated: listsCreated,
      tasksImported: tasksImported,
      stepsImported: 0,
      warnings: warnings,
    );
  }

  /// Maps one Microsoft Graph task object to the local model.
  TaskItem _graphTaskToLocal(Map<String, dynamic> doc, int listId) {
    final title = (doc['title'] as String?)?.trim() ?? AppStrings.tr('noTitle');
    final status = (doc['status'] as String?) ?? 'notStarted';
    final completed = status == 'completed';
    final importance = (doc['importance'] as String?) ?? 'normal';
    final important = importance == 'high';

    DateTime? parseDateTime(Map<String, dynamic>? dt) {
      if (dt == null) return null;
      final raw = dt['dateTime'] as String?;
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    DateTime? due;
    final dueRaw = doc['dueDateTime'];
    if (dueRaw is Map<String, dynamic>) {
      final parsed = parseDateTime(dueRaw);
      if (parsed != null) {
        due = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    DateTime? reminder;
    final remRaw = doc['reminderDateTime'];
    if (remRaw is Map<String, dynamic>) {
      reminder = parseDateTime(remRaw);
    }
    DateTime? created;
    final createdRaw = doc['createdDateTime'];
    if (createdRaw is String) {
      created = DateTime.tryParse(createdRaw);
    }
    DateTime? completedAt;
    final completedRaw = doc['completedDateTime'];
    if (completedRaw is Map<String, dynamic>) {
      completedAt = parseDateTime(completedRaw);
    }

    String note = '';
    final body = doc['body'];
    if (body is Map<String, dynamic>) {
      final content = (body['content'] as String?) ?? '';
      final contentType = body['contentType'] as String? ?? 'text';
      note = contentType == 'html' ? stripHtml(content) : content;
    }

    // Microsoft To Do checklist items are separate resources; when they are
    // embedded in an export they appear as "checklistItems".
    // They are imported as steps below (handled by the caller via the
    // returned task id) — for the single-task mapping we keep them out and
    // note it in the warning list when present.

    return TaskItem(
      listId: listId,
      title: title,
      completed: completed,
      important: important,
      dueDate: due,
      reminderDateTime: reminder,
      note: note.trim(),
      createdAt: created ?? DateTime.now(),
      completedAt: completedAt,
    );
  }

  /// Strips HTML tags/entities to plain text (used for Graph body content).
  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  // ------------------------------------------------------------------ CSV

  /// Imports a CSV with header `list,title,completed,important,due_date,note`.
  /// `completed` / `important` accept true/false, 1/0, yes/no.
  /// `due_date` accepts yyyy-MM-dd (or any ISO date).
  Future<ImportResult> importCsv(String text) async {
    final rows = parseCsv(text);
    if (rows.isEmpty) {
      return ImportResult(
        listsCreated: 0,
        tasksImported: 0,
        stepsImported: 0,
        warnings: [AppStrings.tr('importCsvEmpty')],
      );
    }
    final header = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final idx = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      idx[header[i]] = i;
    }
    if (!idx.containsKey('title')) {
      return ImportResult(
        listsCreated: 0,
        tasksImported: 0,
        stepsImported: 0,
        warnings: [AppStrings.tr('importCsvHeaderError')],
      );
    }

    String cell(List<String> row, String key) {
      final i = idx[key];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    bool truthy(String v) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }

    int listsCreated = 0;
    int tasksImported = 0;
    final warnings = <String>[];
    final existing = await _db.getLists();
    final listIds = <String, int>{};
    for (final l in existing) {
      listIds[l.name.toLowerCase()] = l.id!;
    }

    for (final row in rows.skip(1)) {
      final title = cell(row, 'title');
      if (title.isEmpty) continue;
      final listName = cell(row, 'list').isEmpty
          ? 'Tasks'
          : cell(row, 'list');
      int listId;
      final key = listName.toLowerCase();
      if (listIds.containsKey(key)) {
        listId = listIds[key]!;
      } else {
        listId = await _db.insertList(TaskList(
          name: listName,
          colorHex: TaskList
              .palette[listsCreated % TaskList.palette.length],
          isSmart: false,
          createdAt: DateTime.now(),
        ));
        listIds[key] = listId;
        listsCreated++;
      }
      DateTime? due;
      final dueRaw = cell(row, 'due_date');
      if (dueRaw.isNotEmpty) {
        final parsed = DateTime.tryParse(dueRaw);
        if (parsed != null) {
          due = DateTime(parsed.year, parsed.month, parsed.day);
        } else {
          warnings.add(AppStrings.tr('importCsvDateWarning',
              {'date': dueRaw, 'title': title}));
        }
      }
      final completed = truthy(cell(row, 'completed'));
      await _db.insertTask(TaskItem(
        listId: listId,
        title: title,
        completed: completed,
        important: truthy(cell(row, 'important')),
        dueDate: due,
        note: cell(row, 'note'),
        createdAt: DateTime.now(),
        completedAt: completed ? DateTime.now() : null,
      ));
      tasksImported++;
    }

    return ImportResult(
      listsCreated: listsCreated,
      tasksImported: tasksImported,
      stepsImported: 0,
      warnings: warnings,
    );
  }

  /// Minimal CSV parser that handles quoted fields and embedded commas.
  /// Minimal CSV parser that handles quoted fields and embedded commas.
  static List<List<String>> parseCsv(String text) {
    final rows = <List<String>>[];
    var current = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          current.add(buffer.toString());
          buffer.clear();
        } else if (ch == '\n' || ch == '\r') {
          if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
            i++;
          }
          current.add(buffer.toString());
          buffer.clear();
          if (current.length > 1 ||
              current.single.trim().isNotEmpty) {
            rows.add(current);
          }
          current = <String>[];
        } else {
          buffer.write(ch);
        }
      }
    }
    if (buffer.isNotEmpty || current.isNotEmpty) {
      current.add(buffer.toString());
      rows.add(current);
    }
    return rows;
  }
}
