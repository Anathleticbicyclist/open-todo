import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/task_item.dart';
import '../store/todo_store.dart';
import '../widgets/task_detail_pane.dart';

/// Full-screen detail page for phones (narrow screens). The same
/// [TaskDetailPane] is used on wide screens as a side pane.
class TaskDetailPage extends StatelessWidget {
  final TaskItem task;
  final TodoStore store;

  const TaskDetailPage({
    super.key,
    required this.task,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        // Re-read the task so edits made in the pane are reflected.
        final current = store.tasks
            .where((t) => t.id == task.id)
            .firstOrNull ??
            store.searchResults
                .where((t) => t.id == task.id)
                .firstOrNull ??
            task;
        return Scaffold(
          appBar: AppBar(
            title: Text(AppStrings.tr('taskDetails')),
          ),
          body: TaskDetailPane(task: current, store: store),
        );
      },
    );
  }
}
