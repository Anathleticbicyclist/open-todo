import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../models/task_item.dart';
import '../models/task_list.dart';
import '../theme.dart';
import '../l10n/language_provider.dart';
import '../services/settings_service.dart';
import '../store/todo_store.dart';
import '../widgets/empty_state.dart';
import '../widgets/sidebar.dart';
import '../widgets/task_detail_pane.dart';
import '../widgets/task_row.dart';
import 'settings_screen.dart';
import 'task_detail_page.dart';

/// Main screen: sidebar + task list + detail pane on wide screens
/// (Windows / tablet), drawer + list with pushed detail on phones.
class HomeScreen extends StatelessWidget {
  final TodoStore store;
  final SettingsService settings;
  final LanguageProvider language;

  const HomeScreen({
    super.key,
    required this.store,
    required this.settings,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return _WideLayout(store: store, settings: settings, language: language);
            }
            return _NarrowLayout(store: store, settings: settings, language: language);
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------- wide layout

class _WideLayout extends StatelessWidget {
  final TodoStore store;
  final SettingsService settings;
  final LanguageProvider language;

  const _WideLayout(
      {required this.store, required this.settings, required this.language});

  @override
  Widget build(BuildContext context) {
    final selectedTask = _selectedTask();
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Sidebar(
              store: store,
              onOpenSettings: () => _openSettings(context),
              onCloseDrawer: () {},
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: TaskListArea(store: store, wide: true),
          ),
          if (selectedTask != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 360,
              child: TaskDetailPane(
                task: selectedTask,
                store: store,
                onClose: () => store.selectTask(null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TaskItem? _selectedTask() {
    final id = store.selectedTaskId;
    if (id == null) return null;
    for (final t in store.tasks) {
      if (t.id == id) return t;
    }
    // The selected task may not be in the current list (e.g. after a
    // search); fall back to the search results.
    for (final t in store.searchResults) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
        store: store, settings: settings, language: language,
      ),
      ),
    );
  }
}

// ----------------------------------------------------------- narrow layout

class _NarrowLayout extends StatelessWidget {
  final TodoStore store;
  final SettingsService settings;
  final LanguageProvider language;

  const _NarrowLayout(
      {required this.store, required this.settings, required this.language});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(store.isSearching
            ? AppStrings.tr('search')
            : (store.selectedList != null
                ? store.listNameOf(store.selectedListId)
                : AppStrings.tr('appTitle'))),
      ),
      drawer: Drawer(
        child: Sidebar(
          store: store,
          onOpenSettings: () => _openSettings(context),
          onCloseDrawer: () => Navigator.of(context).pop(),
        ),
      ),
      body: TaskListArea(store: store, wide: false),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
        store: store, settings: settings, language: language,
      ),
      ),
    );
  }
}

// -------------------------------------------------------------- task list

class TaskListArea extends StatefulWidget {
  final TodoStore store;
  final bool wide;

  const TaskListArea({
    super.key,
    required this.store,
    required this.wide,
  });

  @override
  State<TaskListArea> createState() => _TaskListAreaState();
}

class _TaskListAreaState extends State<TaskListArea> {
  final _addController = TextEditingController();
  DateTime? _pendingDue;
  DateTime? _pendingReminder;
  RepeatOption _pendingRepeat = RepeatOption.none;
  bool _addHasText = false;

  TodoStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _addController.addListener(() {
      final hasText = _addController.text.trim().isNotEmpty;
      if (hasText != _addHasText) {
        setState(() => _addHasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlanned = !store.isSearching &&
        store.selectedListId == TaskList.plannedId;
    final tasks = store.isSearching ? store.searchResults : store.tasks;

    return Column(
      children: [
        // Header.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.isSearching
                          ? AppStrings.tr('searchResults')
                          : store.listNameOf(store.selectedListId),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!store.isSearching)
                      Text(
                        _headerSubtitle(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<SortBy>(
                icon: const Icon(Icons.sort),
                tooltip: AppStrings.tr('sort'),
                onSelected: (s) => store.setSort(s),
                itemBuilder: (context) => SortBy.values
                    .map((s) => CheckedPopupMenuItem<SortBy>(
                          value: s,
                          checked: store.sortBy == s,
                          child: Text(s.label),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        // Task list.
        Expanded(
          child: tasks.isEmpty
              ? EmptyState(
                  icon: store.isSearching
                      ? Icons.search_off_outlined
                      : _emptyIcon(),
                  title: store.isSearching
                      ? AppStrings.tr('noResultsTitle')
                      : _emptyTitle(),
                  subtitle: store.isSearching
                      ? AppStrings.tr('noResultsSubtitle')
                      : _emptySubtitle(),
                )
              : isPlanned
                  ? _PlannedGroups(store: store)
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, i) {
                        final task = tasks[i];
                        return TaskRow(
                          task: task,
                          store: store,
                          selected: store.selectedTaskId == task.id,
                          showListName: store.isSearching ||
                              TaskList.isSmartId(store.selectedListId),
                          onTap: () => _openTask(context, task),
                        );
                      },
                    ),
        ),
        // Quick add bar.
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3B3A39)
                    : const Color(0xFFEDEBE9),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.add, color: Color(0xFF0078D4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      decoration: InputDecoration(
                        hintText: AppStrings.tr('addTask'),
                        border: InputBorder.none,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (v) => _submitAdd(),
                    ),
                  ),
                  // Quick actions appear while typing, like Microsoft To Do:
                  // set a due date, a reminder or a repeat on the new task.
                  if (_addHasText) ...[
                    _QuickAddButton(
                      icon: Icons.calendar_today_outlined,
                      tooltip: AppStrings.tr('dueDate'),
                      active: _pendingDue != null,
                      onPressed: _pickQuickDue,
                    ),
                    _QuickAddButton(
                      icon: Icons.notifications_outlined,
                      tooltip: AppStrings.tr('remindMe'),
                      active: _pendingReminder != null,
                      onPressed: _pickQuickReminder,
                    ),
                    _QuickAddButton(
                      icon: Icons.repeat,
                      tooltip: AppStrings.tr('repeat'),
                      active: _pendingRepeat != RepeatOption.none,
                      onPressed: _pickQuickRepeat,
                    ),
                  ],
                  if (store.selectedListId == TaskList.myDayId)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.wb_sunny_outlined,
                          size: 18, color: Color(0xFF0078D4)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: AppStrings.tr('addTaskTooltip'),
                    onPressed: _submitAdd,
                  ),
                ],
              ),
              if (_pendingDue != null ||
                  _pendingReminder != null ||
                  _pendingRepeat != RepeatOption.none)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 32),
                  child: Row(
                    children: [
                      if (_pendingDue != null)
                        _PendingChip(
                          label: DateFormat('EEE, MMM d',
                                  AppStrings.dateLocale)
                              .format(_pendingDue!),
                          onClear: () =>
                              setState(() => _pendingDue = null),
                        ),
                      if (_pendingReminder != null)
                        _PendingChip(
                          label: DateFormat('MMM d, HH:mm',
                                  AppStrings.dateLocale)
                              .format(_pendingReminder!),
                          onClear: () =>
                              setState(() => _pendingReminder = null),
                        ),
                      if (_pendingRepeat != RepeatOption.none)
                        _PendingChip(
                          label: _pendingRepeat.label,
                          onClear: () => setState(
                              () => _pendingRepeat = RepeatOption.none),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickQuickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pendingDue ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() =>
        _pendingDue = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickQuickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pendingReminder ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_pendingReminder ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() => _pendingReminder = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickQuickRepeat() async {
    final chosen = await showDialog<RepeatOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppStrings.tr('repeat')),
        children: RepeatOption.values
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(r),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.label)),
                      if (r == _pendingRepeat)
                        const Icon(Icons.check, color: Color(0xFF0078D4)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (chosen != null) {
      setState(() => _pendingRepeat = chosen);
    }
  }

  Future<void> _submitAdd() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    final due = _pendingDue;
    final reminder = _pendingReminder;
    final repeat = _pendingRepeat;
    setState(() {
      _pendingDue = null;
      _pendingReminder = null;
      _pendingRepeat = RepeatOption.none;
    });
    await store.addTask(
      text,
      dueDate: due,
      reminderDateTime: reminder,
      repeat: repeat,
    );
  }

  void _openTask(BuildContext context, TaskItem task) {
    store.selectTask(task.id);
    if (!widget.wide) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaskDetailPage(task: task, store: store),
        ),
      );
    }
  }

  String _headerSubtitle() {
    final now = DateTime.now();
    final id = store.selectedListId;
    if (id == TaskList.myDayId) {
      return DateFormat('EEEE, MMMM d', AppStrings.dateLocale).format(now);
    }
    final open = store.tasks.where((t) => !t.completed).length;
    final done = store.tasks.length - open;
    if (store.tasks.isEmpty) return '';
    return AppStrings.tr('openCompleted', {
      'open': '$open',
      'done': '$done',
    });
  }

  IconData _emptyIcon() {
    switch (store.selectedListId) {
      case TaskList.myDayId:
        return Icons.wb_sunny_outlined;
      case TaskList.importantId:
        return Icons.star_border;
      case TaskList.plannedId:
        return Icons.calendar_today_outlined;
      case TaskList.allTasksId:
        return Icons.check_circle_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _emptyTitle() {
    switch (store.selectedListId) {
      case TaskList.myDayId:
        return AppStrings.tr('emptyMyDayTitle');
      case TaskList.importantId:
        return AppStrings.tr('emptyImportantTitle');
      case TaskList.plannedId:
        return AppStrings.tr('emptyPlannedTitle');
      case TaskList.allTasksId:
        return AppStrings.tr('emptyAllTitle');
      default:
        return AppStrings.tr('emptyListTitle');
    }
  }

  String _emptySubtitle() {
    switch (store.selectedListId) {
      case TaskList.myDayId:
        return AppStrings.tr('emptyMyDaySubtitle');
      case TaskList.importantId:
        return AppStrings.tr('emptyImportantSubtitle');
      case TaskList.plannedId:
        return AppStrings.tr('emptyPlannedSubtitle');
      default:
        return AppStrings.tr('emptyAllSubtitle');
    }
  }
}

// ---------------------------------------------------------- planned groups

class _PlannedGroups extends StatelessWidget {
  final TodoStore store;

  const _PlannedGroups({required this.store});

  @override
  Widget build(BuildContext context) {
    final groups = _groupPlanned(store.tasks);
    final order = [
      AppStrings.tr('overdue'),
      AppStrings.tr('today'),
      AppStrings.tr('tomorrow'),
      AppStrings.tr('thisWeek'),
      AppStrings.tr('later'),
    ];
    return ListView(
      children: [
        for (final name in order)
          if (groups.containsKey(name) && groups[name]!.isNotEmpty)
            _PlannedGroup(
              title: name,
              tasks: groups[name]!,
              store: store,
            ),
      ],
    );
  }

  Map<String, List<TaskItem>> _groupPlanned(List<TaskItem> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));
    final groups = <String, List<TaskItem>>{
      AppStrings.tr('overdue'): [],
      AppStrings.tr('today'): [],
      AppStrings.tr('tomorrow'): [],
      AppStrings.tr('thisWeek'): [],
      AppStrings.tr('later'): [],
    };
    for (final t in tasks) {
      final due = t.dueDate;
      if (due == null) continue;
      final d = DateTime(due.year, due.month, due.day);
      final overdueKey = AppStrings.tr('overdue');
      final todayKey = AppStrings.tr('today');
      final tomorrowKey = AppStrings.tr('tomorrow');
      final weekKey = AppStrings.tr('thisWeek');
      final laterKey = AppStrings.tr('later');
      if (d.isBefore(today)) {
        groups[overdueKey]!.add(t);
      } else if (d == today) {
        groups[todayKey]!.add(t);
      } else if (d == tomorrow) {
        groups[tomorrowKey]!.add(t);
      } else if (d.isBefore(weekEnd)) {
        groups[weekKey]!.add(t);
      } else {
        groups[laterKey]!.add(t);
      }
    }
    return groups;
  }
}

class _PlannedGroup extends StatelessWidget {
  final String title;
  final List<TaskItem> tasks;
  final TodoStore store;

  const _PlannedGroup({
    required this.title,
    required this.tasks,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = title == AppStrings.tr('overdue');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isOverdue
                  ? const Color(0xFFA4262C)
                  : theme.colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
        ),
        for (final task in tasks)
          TaskRow(
            task: task,
            store: store,
            selected: store.selectedTaskId == task.id,
            showListName: true,
            onTap: () => store.selectTask(task.id),
          ),
      ],
    );
  }
}

// ------------------------------------------------------- quick-add helpers

/// Small icon button in the quick-add bar. Turns blue when a value is set.
class _QuickAddButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  const _QuickAddButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? (isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }
}

/// A small chip under the quick-add bar showing a pending due date /
/// reminder / repeat, with an X to clear it.
class _PendingChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _PendingChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label),
        labelStyle: Theme.of(context).textTheme.bodySmall,
        backgroundColor:
            isDark ? const Color(0xFF2D2C2B) : const Color(0xFFF3F2F1),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onClear,
      ),
    );
  }
}
