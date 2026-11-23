import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../l10n/app_strings.dart';
import '../models/step_item.dart';
import '../models/task_item.dart';
import '../models/task_list.dart';

/// SQLite storage for Open To Do.
///
/// Uses `sqflite` on Android/iOS and `sqflite_common_ffi` on Windows/macOS/
/// Linux (desktop), so the same code runs on every platform. All data lives
/// in a single local file — no account, no server.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'open_todo.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // Desktop platforms need the ffi implementation.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        isSmart INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        listId INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        important INTEGER NOT NULL DEFAULT 0,
        myDay INTEGER NOT NULL DEFAULT 0,
        myDayDate TEXT,
        dueDate TEXT,
        reminderDateTime TEXT,
        repeat TEXT NOT NULL DEFAULT 'none',
        note TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        completedAt TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_tasks_list ON tasks(listId)');
    await db.execute(
        'CREATE INDEX idx_tasks_due ON tasks(dueDate)');
    await db.execute(
        'CREATE INDEX idx_steps_task ON steps(taskId)');

    // Seed the four smart lists (fixed ids) and the default "Tasks" list.
    final now = DateTime.now().toIso8601String();
    const smart = [
      {'id': TaskList.myDayId, 'name': 'My Day', 'color': '#0078D4'},
      {'id': TaskList.importantId, 'name': 'Important', 'color': '#A4262C'},
      {'id': TaskList.plannedId, 'name': 'Planned', 'color': '#038387'},
      {'id': TaskList.allTasksId, 'name': 'All Tasks', 'color': '#0078D4'},
    ];
    for (final s in smart) {
      await db.insert('lists', {
        'id': s['id'],
        'name': s['name'],
        'color': s['color'],
        'isSmart': 1,
        'createdAt': now,
      });
    }
    await db.insert('lists', {
      'id': TaskList.defaultListId,
      'name': 'Tasks',
      'color': '#0078D4',
      'isSmart': 0,
      'createdAt': now,
    });
  }

  // ---------------------------------------------------------------- lists

  Future<List<TaskList>> getLists() async {
    final db = await database;
    final rows = await db.query('lists', orderBy: 'isSmart DESC, id ASC');
    return rows.map(TaskList.fromMap).toList();
  }

  Future<TaskList?> getList(int id) async {
    final db = await database;
    final rows = await db.query('lists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TaskList.fromMap(rows.first);
  }

  Future<int> insertList(TaskList list) async {
    final db = await database;
    final map = list.toMap()..remove('id');
    return db.insert('lists', map);
  }

  Future<void> updateList(TaskList list) async {
    final db = await database;
    await db.update('lists', list.toMap(),
        where: 'id = ?', whereArgs: [list.id]);
  }

  /// Deletes a list and everything in it (its tasks and their steps).
  Future<void> deleteList(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final tasks = await txn.query('tasks',
          columns: ['id'], where: 'listId = ?', whereArgs: [id]);
      for (final t in tasks) {
        await txn.delete('steps',
            where: 'taskId = ?', whereArgs: [t['id']]);
      }
      await txn.delete('tasks', where: 'listId = ?', whereArgs: [id]);
      await txn.delete('lists', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> countTasksInList(int listId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE listId = ? AND completed = 0',
      [listId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ---------------------------------------------------------------- tasks

  Future<List<TaskItem>> getTasksForList(int listId) async {
    final db = await database;
    final rows = await db.query('tasks',
        where: 'listId = ?', whereArgs: [listId], orderBy: 'createdAt ASC');
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> getAllTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'createdAt ASC');
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> getMyDayTasks() async {
    final db = await database;
    final today = _dateOnly(DateTime.now());
    final rows = await db.query(
      'tasks',
      where: 'myDay = 1 AND myDayDate = ?',
      whereArgs: [today.toIso8601String()],
      orderBy: 'createdAt ASC',
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> getImportantTasks() async {
    final db = await database;
    final rows = await db.query('tasks',
        where: 'important = 1', orderBy: 'createdAt ASC');
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> getPlannedTasks() async {
    final db = await database;
    final rows = await db.query('tasks',
        where: 'dueDate IS NOT NULL', orderBy: 'dueDate ASC, createdAt ASC');
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> searchTasks(String query) async {
    final db = await database;
    final like = '%$query%';
    final rows = await db.query(
      'tasks',
      where: 'title LIKE ? OR note LIKE ?',
      whereArgs: [like, like],
      orderBy: 'createdAt ASC',
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<TaskItem?> getTask(int id) async {
    final db = await database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TaskItem.fromMap(rows.first);
  }

  Future<int> insertTask(TaskItem task) async {
    final db = await database;
    final map = task.toMap()..remove('id');
    return db.insert('tasks', map);
  }

  Future<void> updateTask(TaskItem task) async {
    final db = await database;
    await db.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('steps', where: 'taskId = ?', whereArgs: [id]);
      await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteCompletedTasks() async {
    final db = await database;
    await db.transaction((txn) async {
      final done = await txn.query('tasks',
          columns: ['id'], where: 'completed = 1');
      for (final t in done) {
        await txn.delete('steps',
            where: 'taskId = ?', whereArgs: [t['id']]);
      }
      await txn.delete('tasks', where: 'completed = 1');
    });
  }

  /// Seeds three welcome tasks the first time the app runs with an empty
  /// task list (fresh install, or an existing install that never had a
  /// task). Called once, guarded by a flag in the store, so a user who
  /// deletes everything on purpose does not get them back.
  Future<void> seedWelcomeTasksIfEmpty() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM tasks');
    if ((Sqflite.firstIntValue(rows) ?? 0) > 0) return;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final welcome = [
      TaskItem(
        listId: TaskList.defaultListId,
        title: AppStrings.tr('welcomeTask1'),
        note: AppStrings.tr('welcomeNote1'),
        myDay: true,
        myDayDate: today,
        createdAt: now,
      ),
      TaskItem(
        listId: TaskList.defaultListId,
        title: AppStrings.tr('welcomeTask2'),
        myDay: true,
        myDayDate: today,
        createdAt: now,
      ),
      TaskItem(
        listId: TaskList.defaultListId,
        title: AppStrings.tr('welcomeTask3'),
        important: true,
        myDay: true,
        myDayDate: today,
        createdAt: now,
      ),
    ];
    for (final task in welcome) {
      await insertTask(task);
    }
  }

  /// My Day resets every day: tasks added to My Day on a previous day drop
  /// out automatically, exactly like Microsoft To Do.
  Future<void> resetStaleMyDay() async {
    final db = await database;
    final today = _dateOnly(DateTime.now()).toIso8601String();
    await db.update(
      'tasks',
      {'myDay': 0, 'myDayDate': null},
      where: 'myDay = 1 AND myDayDate IS NOT NULL AND myDayDate < ?',
      whereArgs: [today],
    );
  }

  Future<int> countMyDay() async {
    final db = await database;
    final today = _dateOnly(DateTime.now()).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE myDay = 1 AND myDayDate = ? AND completed = 0',
      [today],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countImportant() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE important = 1 AND completed = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countPlanned() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE dueDate IS NOT NULL AND completed = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countAllOpen() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE completed = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ---------------------------------------------------------------- steps

  Future<List<StepItem>> getSteps(int taskId) async {
    final db = await database;
    final rows = await db.query('steps',
        where: 'taskId = ?', whereArgs: [taskId], orderBy: 'sortOrder ASC');
    return rows.map(StepItem.fromMap).toList();
  }

  Future<int> insertStep(StepItem step) async {
    final db = await database;
    final map = step.toMap()..remove('id');
    return db.insert('steps', map);
  }

  Future<void> updateStep(StepItem step) async {
    final db = await database;
    await db.update('steps', step.toMap(),
        where: 'id = ?', whereArgs: [step.id]);
  }

  Future<void> deleteStep(int id) async {
    final db = await database;
    await db.delete('steps', where: 'id = ?', whereArgs: [id]);
  }

  Future<(int total, int done)> stepProgress(int taskId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total, COALESCE(SUM(completed), 0) AS done FROM steps WHERE taskId = ?',
      [taskId],
    );
    final total = (rows.first['total'] as int?) ?? 0;
    final done = (rows.first['done'] as int?) ?? 0;
    return (total, done);
  }

  // ------------------------------------------------------------ utilities

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Wipes everything (used only by the "clear all data" path, if any).
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('steps');
      await txn.delete('tasks');
      await txn.delete('lists', where: 'isSmart = 0');
    });
  }
}
