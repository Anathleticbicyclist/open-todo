import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../models/step_item.dart';
import '../models/task_item.dart';
import '../store/todo_store.dart';
import '../theme.dart';
import 'circle_checkbox.dart';

/// The right-hand detail pane (wide screens) / full page (phones).
/// Edits title, steps, due date, reminder, repeat, note and My Day, and
/// can delete the task — the same feature set as Microsoft To Do's detail
/// pane.
class TaskDetailPane extends StatefulWidget {
  final TaskItem task;
  final TodoStore store;
  final VoidCallback? onClose;

  const TaskDetailPane({
    super.key,
    required this.task,
    required this.store,
    this.onClose,
  });

  @override
  State<TaskDetailPane> createState() => _TaskDetailPaneState();
}

class _TaskDetailPaneState extends State<TaskDetailPane> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _stepController;
  late final FocusNode _titleFocus;
  late final FocusNode _noteFocus;
  List<StepItem> _steps = [];
  bool _loadingSteps = true;

  TaskItem get task => widget.task;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: task.title);
    _noteController = TextEditingController(text: task.note);
    _stepController = TextEditingController();
    _titleFocus = FocusNode();
    _noteFocus = FocusNode();
    _titleFocus.addListener(_onTitleFocusChange);
    _noteFocus.addListener(_onNoteFocusChange);
    _loadSteps();
  }

  @override
  void didUpdateWidget(TaskDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _titleController.text = task.title;
      _noteController.text = task.note;
      _loadSteps();
    } else {
      // Same task, values may have changed from elsewhere (e.g. star).
      if (_titleController.text != task.title && !_titleFocus.hasFocus) {
        _titleController.text = task.title;
      }
      if (_noteController.text != task.note && !_noteFocus.hasFocus) {
        _noteController.text = task.note;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _stepController.dispose();
    _titleFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSteps() async {
    setState(() => _loadingSteps = true);
    final steps = await widget.store.getSteps(task.id!);
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _loadingSteps = false;
    });
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) _saveTitle();
  }

  void _onNoteFocusChange() {
    if (!_noteFocus.hasFocus) _saveNote();
  }

  Future<void> _saveTitle() async {
    final text = _titleController.text.trim();
    if (text.isEmpty) {
      _titleController.text = task.title;
      return;
    }
    if (text != task.title) {
      await widget.store.updateTask(task.copyWith(title: text));
    }
  }

  Future<void> _saveNote() async {
    final text = _noteController.text;
    if (text != task.note) {
      await widget.store.updateTask(task.copyWith(note: text));
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final due = DateTime(picked.year, picked.month, picked.day);
    await widget.store.updateTask(task.copyWith(dueDate: due));
    if (mounted) setState(() {});
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: task.reminderDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          task.reminderDateTime ?? DateTime.now()),
    );
    if (time == null) return;
    final reminder = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    await widget.store.updateTask(
        task.copyWith(reminderDateTime: reminder));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue;

    return Container(
      color: isDark ? const Color(0xFF252423) : const Color(0xFFF9F9F9),
      child: Column(
        children: [
          // Header: complete toggle + star + close.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                CircleCheckbox(
                  checked: task.completed,
                  onChanged: (_) => widget.store.toggleComplete(task),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    task.important ? Icons.star : Icons.star_border,
                    color: task.important ? accent : null,
                  ),
                  tooltip: task.important
                      ? AppStrings.tr('removeImportant')
                      : AppStrings.tr('markImportant'),
                  onPressed: () => widget.store.toggleImportant(task),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: AppStrings.tr('closeDetails'),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                // Title.
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: AppStrings.tr('taskTitleHint'),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _saveTitle(),
                ),
                const Divider(height: 8),
                // Steps.
                if (_loadingSteps)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else
                  for (final step in _steps)
                    _StepRow(
                      step: step,
                      onToggle: () async {
                        await widget.store.toggleStep(step);
                        await _loadSteps();
                      },
                      onDelete: () async {
                        await widget.store.deleteStep(step.id!);
                        await _loadSteps();
                      },
                    ),
                Row(
                  children: [
                    Icon(Icons.add,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _stepController,
                        decoration: InputDecoration(
                          hintText: AppStrings.tr('addStep'),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (v) async {
                          if (v.trim().isEmpty) return;
                          await widget.store.addStep(task.id!, v);
                          _stepController.clear();
                          await _loadSteps();
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // My Day.
                _DetailRow(
                  icon: Icons.wb_sunny_outlined,
                  label: AppStrings.tr('addToMyDay'),
                  trailing: Switch(
                    value: task.isInMyDayToday,
                    activeColor: accent,
                    onChanged: (_) => widget.store.toggleMyDay(task),
                  ),
                  onTap: () => widget.store.toggleMyDay(task),
                ),
                // Due date.
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: AppStrings.tr('dueDate'),
                  value: task.dueDate == null
                      ? null
                      : DateFormat('EEE, MMM d, y',
                              AppStrings.dateLocale)
                          .format(task.dueDate!),
                  onTap: _pickDueDate,
                  onClear: task.dueDate == null
                      ? null
                      : () async {
                          await widget.store
                              .updateTask(task.copyWith(clearDueDate: true));
                          if (mounted) setState(() {});
                        },
                ),
                // Quick due-date shortcuts.
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 4),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _QuickChip(
                        label: AppStrings.tr('today'),
                        onTap: () async {
                          final now = DateTime.now();
                          await widget.store.updateTask(task.copyWith(
                              dueDate: DateTime(now.year, now.month, now.day)));
                          if (mounted) setState(() {});
                        },
                      ),
                      _QuickChip(
                        label: AppStrings.tr('tomorrow'),
                        onTap: () async {
                          final t =
                              DateTime.now().add(const Duration(days: 1));
                          await widget.store.updateTask(task.copyWith(
                              dueDate: DateTime(t.year, t.month, t.day)));
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                // Reminder.
                _DetailRow(
                  icon: Icons.notifications_outlined,
                  label: AppStrings.tr('remindMe'),
                  value: task.reminderDateTime == null
                      ? null
                      : DateFormat('EEE, MMM d, y · HH:mm',
                              AppStrings.dateLocale)
                          .format(task.reminderDateTime!),
                  onTap: _pickReminder,
                  onClear: task.reminderDateTime == null
                      ? null
                      : () async {
                          await widget.store.updateTask(
                              task.copyWith(clearReminder: true));
                          if (mounted) setState(() {});
                        },
                ),
                // Repeat.
                _DetailRow(
                  icon: Icons.repeat,
                  label: AppStrings.tr('repeat'),
                  value: task.repeat == RepeatOption.none
                      ? null
                      : task.repeat.label,
                  trailing: DropdownButton<RepeatOption>(
                    value: task.repeat,
                    underline: const SizedBox.shrink(),
                    items: RepeatOption.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: (r) async {
                      if (r == null) return;
                      await widget.store.updateTask(task.copyWith(repeat: r));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const Divider(height: 16),
                // Note.
                TextField(
                  controller: _noteController,
                  focusNode: _noteFocus,
                  decoration: InputDecoration(
                    hintText: AppStrings.tr('addNote'),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.tr('createdOn', {
                    'date': DateFormat('MMM d, y · HH:mm',
                            AppStrings.dateLocale)
                        .format(task.createdAt),
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 16),
                // Delete.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(AppStrings.tr('deleteTask')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppStrings.tr('deleteTaskTitle')),
                          content: Text(AppStrings.tr(
                              'deleteTaskMessage',
                              {'title': task.title})),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              child: Text(AppStrings.tr('cancel')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.danger,
                              ),
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              child: Text(AppStrings.tr('delete')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await widget.store.deleteTask(task.id!);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final StepItem step;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _StepRow({
    required this.step,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleCheckbox(
          checked: step.completed,
          onChanged: (_) => onToggle(),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            step.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration:
                  step.completed ? TextDecoration.lineThrough : null,
              color: step.completed
                  ? theme.colorScheme.onSurface.withOpacity(0.55)
                  : null,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: AppStrings.tr('deleteStep'),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: value == null
                      ? theme.colorScheme.onSurface.withOpacity(0.7)
                      : null,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: AppStrings.tr('clear'),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor:
          isDark ? const Color(0xFF2D2C2B) : const Color(0xFFF3F2F1),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: Theme.of(context).textTheme.bodySmall,
    );
  }
}
