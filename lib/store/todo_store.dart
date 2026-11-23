import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

import '../db/database.dart';
import '../models/step_item.dart';
import '../models/task_item.dart';
import '../models/task_list.dart';

/// Sort orders available in a list view.
enum SortBy { importance, dueDate, createdAt, alphabetical }

extension SortByLabel on SortBy {
  String get label {
    switch (this) {
      case SortBy.importance:
        return AppStrings.tr('sortImportance');
      case SortBy.dueDate:
        return AppStrings.tr('sortDueDate');
      case SortBy.createdAt:
        return AppStrings.tr('sortCreationDate');
      case SortBy.alphabetical:
        return AppStrings.tr('sortAlphabetical');
    }
  }
}

/// Central state for the app. The UI listens to this ChangeNotifier and
/// rebuilds when data changes. All persistence goes through [AppDatabase].
class TodoStore extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;

  List<TaskList> lists = [];
  List<TaskItem> tasks = [];
  Map<int, int> openCounts = {}; // listId -> open task count
  int myDayCount = 0;
  int importantCount = 0;
  int plannedCount = 0;
  int allOpenCount = 0;

  int selectedListId = TaskList.myDayId;
  int? selectedTaskId;
  String searchQuery = '';
  List<TaskItem> searchResults = [];
  SortBy sortBy = SortBy.createdAt;

  // Step progress cache for the current task list (taskId -> (done, total)).
  Map<int, (int done, int total)> stepProgress = {};

  TaskList? get selectedList {
    for (final l in lists) {
      if (l.id == selectedListId) return l;
    }
    return null;
  }

  bool get isSearching => searchQuery.trim().isNotEmpty;

  List<TaskList> get customLists =>
      lists.where((l) => !l.isSmart).toList();

  /// The display name of a list (used for the list-name chip in smart
  /// views, where a task's own list is shown in its meta line).
  /// Display name for a list: smart lists and the seeded default list are
  /// localized; user-created (or renamed) lists show their stored name.
  String listNameOf(int listId) {
    switch (listId) {
      case TaskList.myDayId:
        return AppStrings.tr('myDay');
      case TaskList.importantId:
        return AppStrings.tr('important');
      case TaskList.plannedId:
        return AppStrings.tr('planned');
      case TaskList.allTasksId:
        return AppStrings.tr('allTasks');
    }
    for (final l in lists) {
      if (l.id == listId) {
        // The seeded default list is stored as "Tasks"; show it localized
        // unless the user renamed it.
        if (l.id == TaskList.defaultListId && l.name == 'Tasks') {
          return AppStrings.tr('tasks');
        }
        return l.name;
      }
    }
    return '';
  }

  Future<void> init() async {
    await _db.resetStaleMyDay();
    // First run with an empty task list: seed three welcome tasks so the
    // app never opens on a blank page. Runs once, ever.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('welcome_seeded') != true) {
      await _db.seedWelcomeTasksIfEmpty();
      await prefs.setBool('welcome_seeded', true);
    }
    await refreshAll();
  }

  Future<void> refreshAll() async {
    lists = await _db.getLists();
    await _refreshCounts();
    await loadTasks();
    notifyListeners();
  }

  Future<void> _refreshCounts() async {
    myDayCount = await _db.countMyDay();
    importantCount = await _db.countImportant();
    plannedCount = await _db.countPlanned();
    allOpenCount = await _db.countAllOpen();
    openCounts = {};
    for (final l in customLists) {
      openCounts[l.id!] = await _db.countTasksInList(l.id!);
    }
  }

  Future<void> selectList(int listId) async {
    selectedListId = listId;
    selectedTaskId = null;
    searchQuery = '';
    searchResults = [];
    await loadTasks();
    notifyListeners();
  }

  Future<void> loadTasks() async {
    List<TaskItem> loaded;
    if (selectedListId == TaskList.myDayId) {
      loaded = await _db.getMyDayTasks();
    } else if (selectedListId == TaskList.importantId) {
      loaded = await _db.getImportantTasks();
    } else if (selectedListId == TaskList.plannedId) {
      loaded = await _db.getPlannedTasks();
    } else if (selectedListId == TaskList.allTasksId) {
      loaded = await _db.getAllTasks();
    } else {
      loaded = await _db.getTasksForList(selectedListId);
    }
    tasks = _sort(loaded);
    await _loadStepProgress();
  }

  /// Sorts by the active criterion, with open tasks before completed ones
  /// (like Microsoft To Do, which keeps completed tasks at the bottom).
  List<TaskItem> _sort(List<TaskItem> input) {
    final list = List<TaskItem>.of(input);
    int compareByCriterion(TaskItem a, TaskItem b) {
      switch (sortBy) {
        case SortBy.importance:
          if (a.important != b.important) return a.important ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        case SortBy.dueDate:
          final da = a.dueDate;
          final db = b.dueDate;
          if (da == null && db == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (da == null) return 1;
          if (db == null) return -1;
          final c = da.compareTo(db);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        case SortBy.createdAt:
          return b.createdAt.compareTo(a.createdAt);
        case SortBy.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    }

    list.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return compareByCriterion(a, b);
    });
    return list;
  }

  Future<void> _loadStepProgress() async {
    stepProgress = {};
    for (final t in tasks) {
      if (t.id == null) continue;
      final (total, done) = await _db.stepProgress(t.id!);
      if (total > 0) stepProgress[t.id!] = (done, total);
    }
  }

  Future<void> setSort(SortBy sort) async {
    sortBy = sort;
    await loadTasks();
    notifyListeners();
  }

  Future<void> setSearchQuery(String q) async {
    searchQuery = q;
    if (q.trim().isEmpty) {
      searchResults = [];
      await loadTasks();
    } else {
      searchResults = _sort(await _db.searchTasks(q.trim()));
    }
    notifyListeners();
  }

  void selectTask(int? taskId) {
    selectedTaskId = taskId;
    notifyListeners();
  }

  // ------------------------------------------------------------ list ops

  Future<TaskList> createList(String name, String colorHex) async {
    final list = TaskList(
      name: name,
      colorHex: colorHex,
      isSmart: false,
      createdAt: DateTime.now(),
    );
    final id = await _db.insertList(list);
    await refreshAll();
    return list.copyWith(id: id);
  }

  Future<void> renameList(TaskList list, String name) async {
    await _db.updateList(list.copyWith(name: name));
    await refreshAll();
  }

  Future<void> recolorList(TaskList list, String colorHex) async {
    await _db.updateList(list.copyWith(colorHex: colorHex));
    await refreshAll();
  }

  Future<void> deleteList(int id) async {
    await _db.deleteList(id);
    if (selectedListId == id) {
      selectedListId = TaskList.myDayId;
    }
    selectedTaskId = null;
    await refreshAll();
  }

  // ------------------------------------------------------------ task ops

  /// Creates a task in [listId]. When adding from a smart list, the task
  /// goes to the default "Tasks" list (like Microsoft To Do).
  /// [dueDate], [reminderDateTime] and [repeat] come from the quick-add
  /// bar's quick-action icons.
  Future<TaskItem> addTask(
    String title, {
    bool addToMyDay = false,
    DateTime? dueDate,
    DateTime? reminderDateTime,
    RepeatOption repeat = RepeatOption.none,
  }) async {
    final targetListId = TaskList.isSmartId(selectedListId)
        ? TaskList.defaultListId
        : selectedListId;
    final now = DateTime.now();
    final inMyDay = addToMyDay || selectedListId == TaskList.myDayId;
    final task = TaskItem(
      listId: targetListId,
      title: title.trim(),
      myDay: inMyDay,
      myDayDate: inMyDay
          ? DateTime(now.year, now.month, now.day)
          : null,
      dueDate: dueDate,
      reminderDateTime: reminderDateTime,
      repeat: repeat,
      createdAt: now,
    );
    final id = await _db.insertTask(task);
    await refreshAll();
    return task.copyWith(id: id);
  }

  Future<void> updateTask(TaskItem task) async {
    await _db.updateTask(task);
    await refreshAll();
  }

  Future<void> deleteTask(int id) async {
    await _db.deleteTask(id);
    if (selectedTaskId == id) selectedTaskId = null;
    await refreshAll();
  }

  Future<void> toggleComplete(TaskItem task) async {
    final now = DateTime.now();
    final updated = task.completed
        ? task.copyWith(completed: false, clearCompletedAt: true)
        : task.copyWith(completed: true, completedAt: now);
    await _db.updateTask(updated);
    await refreshAll();
  }

  Future<void> toggleImportant(TaskItem task) async {
    await _db.updateTask(task.copyWith(important: !task.important));
    await refreshAll();
  }

  Future<void> toggleMyDay(TaskItem task) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updated = task.isInMyDayToday
        ? task.copyWith(myDay: false, clearMyDayDate: true)
        : task.copyWith(myDay: true, myDayDate: today);
    await _db.updateTask(updated);
    await refreshAll();
  }

  Future<void> clearCompleted() async {
    await _db.deleteCompletedTasks();
    selectedTaskId = null;
    await refreshAll();
  }

  // ------------------------------------------------------------ step ops

  Future<List<StepItem>> getSteps(int taskId) => _db.getSteps(taskId);

  Future<void> addStep(int taskId, String title) async {
    final steps = await _db.getSteps(taskId);
    await _db.insertStep(StepItem(
      taskId: taskId,
      title: title.trim(),
      sortOrder: steps.length,
    ));
    await refreshAll();
  }

  Future<void> toggleStep(StepItem step) async {
    await _db.updateStep(step.copyWith(completed: !step.completed));
    await refreshAll();
  }

  Future<void> deleteStep(int id) async {
    await _db.deleteStep(id);
    await refreshAll();
  }
}
