/// Data model for a step (subtask) belonging to a task.
class StepItem {
  final int? id;
  final int taskId;
  final String title;
  final bool completed;
  final int sortOrder;

  const StepItem({
    this.id,
    required this.taskId,
    required this.title,
    this.completed = false,
    this.sortOrder = 0,
  });

  StepItem copyWith({
    int? id,
    int? taskId,
    String? title,
    bool? completed,
    int? sortOrder,
  }) {
    return StepItem(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory StepItem.fromMap(Map<String, dynamic> map) {
    return StepItem(
      id: map['id'] as int?,
      taskId: map['taskId'] as int,
      title: map['title'] as String,
      completed: (map['completed'] as int) == 1,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      'completed': completed ? 1 : 0,
      'sortOrder': sortOrder,
    };
  }
}
