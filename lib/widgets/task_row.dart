import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../models/task_item.dart';
import '../store/todo_store.dart';
import '../theme.dart';
import 'circle_checkbox.dart';

/// One task row in a list, styled after Microsoft To Do:
/// circular checkbox, title, a small meta line, and a star for Important.
class TaskRow extends StatelessWidget {
  final TaskItem task;
  final TodoStore store;
  final bool selected;
  final VoidCallback onTap;
  /// In smart-list views To Do shows which list a task belongs to.
  final bool showListName;

  const TaskRow({
    super.key,
    required this.task,
    required this.store,
    required this.selected,
    required this.onTap,
    this.showListName = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = store.stepProgress[task.id];
    final hasNote = task.note.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? const Color(0xFF2D2C2B)
                  : AppTheme.msBlueLight.withOpacity(0.55))
              : null,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? const Color(0xFF3B3A39)
                  : AppTheme.dividerLight,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CircleCheckbox(
                checked: task.completed,
                onChanged: (_) => store.toggleComplete(task),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: task.completed
                          ? AppTheme.textCompleted
                          : AppTheme.textPrimary,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_hasMeta(task, progress, hasNote))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _MetaLine(
                        task: task,
                        progress: progress,
                        hasNote: hasNote,
                        listName: showListName
                            ? store.listNameOf(task.listId)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                task.important ? Icons.star : Icons.star_border,
                color: task.important
                    ? (isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue)
                    : theme.colorScheme.onSurface.withOpacity(0.45),
              ),
              tooltip: task.important
                  ? AppStrings.tr('removeImportant')
                  : AppStrings.tr('markImportant'),
              onPressed: () => store.toggleImportant(task),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasMeta(TaskItem t, (int done, int total)? p, bool hasNote) {
    return t.dueDate != null ||
        t.reminderDateTime != null ||
        p != null ||
        hasNote ||
        t.isInMyDayToday ||
        showListName;
  }
}

class _MetaLine extends StatelessWidget {
  final TaskItem task;
  final (int done, int total)? progress;
  final bool hasNote;
  final String? listName;

  const _MetaLine({
    required this.task,
    required this.progress,
    required this.hasNote,
    this.listName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final metaColor =
        isDark ? Colors.white60 : AppTheme.textSecondaryLight;
    final small = TextStyle(fontSize: 12, color: metaColor);
    final items = <Widget>[];

    if (listName != null && listName!.isNotEmpty) {
      items.add(_chip(Icons.list, listName!, small, null));
    }
    if (task.isInMyDayToday) {
      items.add(_chip(
        Icons.wb_sunny_outlined,
        AppStrings.tr('myDay'),
        small,
        isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue,
      ));
    }
    if (task.dueDate != null) {
      final due = task.dueDate!;
      final label = _dueLabel(due);
      final overdue = task.isOverdue;
      final isToday = _isToday(due);
      final dueColor = overdue
          ? AppTheme.danger
          : isToday
              ? (isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue)
              : metaColor;
      items.add(_chip(
        Icons.calendar_today_outlined,
        label,
        small.copyWith(
          color: dueColor,
          fontWeight: overdue || isToday ? FontWeight.w600 : null,
        ),
        dueColor,
      ));
    }
    if (task.reminderDateTime != null) {
      items.add(_chip(
        Icons.notifications_outlined,
        DateFormat('MMM d, HH:mm', AppStrings.dateLocale)
            .format(task.reminderDateTime!),
        small,
        null,
      ));
    }
    if (progress != null) {
      items.add(_chip(
        Icons.checklist_outlined,
        AppStrings.tr('stepsOf', {
          'done': '${progress!.$1}',
          'total': '${progress!.$2}',
        }),
        small,
        null,
      ));
    }
    if (hasNote) {
      items.add(_chip(Icons.sticky_note_2_outlined, '', small, null));
    }
    if (task.repeat != RepeatOption.none) {
      items.add(_chip(Icons.repeat, task.repeat.label, small, null));
    }

    return Wrap(spacing: 14, runSpacing: 2, children: items);
  }

  Widget _chip(IconData icon, String label, TextStyle? style, Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? style?.color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(label, style: style),
        ],
      ],
    );
  }

  String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(due.year, due.month, due.day);
    final loc = AppStrings.dateLocale;
    if (d == today) return AppStrings.tr('today');
    if (d == tomorrow) return AppStrings.tr('tomorrow');
    if (d.isBefore(today)) {
      return AppStrings.tr('overdueDate',
          {'date': DateFormat('MMM d', loc).format(d)});
    }
    return DateFormat('EEE, MMM d', loc).format(d);
  }

  bool _isToday(DateTime due) {
    final now = DateTime.now();
    return due.year == now.year &&
        due.month == now.month &&
        due.day == now.day;
  }
}
