import '../l10n/app_strings.dart';

/// Repeat options for a task, stored as a plain string in SQLite.
enum RepeatOption {
  none,
  daily,
  weekdays,
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case RepeatOption.none:
        return AppStrings.tr('repeatNone');
      case RepeatOption.daily:
        return AppStrings.tr('repeatDaily');
      case RepeatOption.weekdays:
        return AppStrings.tr('repeatWeekdays');
      case RepeatOption.weekly:
        return AppStrings.tr('repeatWeekly');
      case RepeatOption.monthly:
        return AppStrings.tr('repeatMonthly');
      case RepeatOption.yearly:
        return AppStrings.tr('repeatYearly');
    }
  }

  static RepeatOption fromString(String value) {
    return RepeatOption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RepeatOption.none,
    );
  }
}

/// Data model for a single task.
class TaskItem {
  final int? id;
  final int listId;
  final String title;
  final bool completed;
  final bool important;
  final bool myDay;
  final DateTime? myDayDate; // date (midnight) the task was added to My Day
  final DateTime? dueDate; // date only
  final DateTime? reminderDateTime;
  final RepeatOption repeat;
  final String note;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int sortOrder;

  const TaskItem({
    this.id,
    required this.listId,
    required this.title,
    this.completed = false,
    this.important = false,
    this.myDay = false,
    this.myDayDate,
    this.dueDate,
    this.reminderDateTime,
    this.repeat = RepeatOption.none,
    this.note = '',
    required this.createdAt,
    this.completedAt,
    this.sortOrder = 0,
  });

  TaskItem copyWith({
    int? id,
    int? listId,
    String? title,
    bool? completed,
    bool? important,
    bool? myDay,
    DateTime? myDayDate,
    bool clearMyDayDate = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? reminderDateTime,
    bool clearReminder = false,
    RepeatOption? repeat,
    String? note,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? sortOrder,
  }) {
    return TaskItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      important: important ?? this.important,
      myDay: myDay ?? this.myDay,
      myDayDate: clearMyDayDate ? null : (myDayDate ?? this.myDayDate),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderDateTime:
          clearReminder ? null : (reminderDateTime ?? this.reminderDateTime),
      repeat: repeat ?? this.repeat,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? v) => v == null ? null : DateTime.parse(v);
    return TaskItem(
      id: map['id'] as int?,
      listId: map['listId'] as int,
      title: map['title'] as String,
      completed: (map['completed'] as int) == 1,
      important: (map['important'] as int) == 1,
      myDay: (map['myDay'] as int) == 1,
      myDayDate: parseDate(map['myDayDate'] as String?),
      dueDate: parseDate(map['dueDate'] as String?),
      reminderDateTime: parseDate(map['reminderDateTime'] as String?),
      repeat: RepeatOption.fromString(map['repeat'] as String? ?? 'none'),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: parseDate(map['completedAt'] as String?),
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    String? iso(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'listId': listId,
      'title': title,
      'completed': completed ? 1 : 0,
      'important': important ? 1 : 0,
      'myDay': myDay ? 1 : 0,
      'myDayDate': iso(myDayDate),
      'dueDate': iso(dueDate),
      'reminderDateTime': iso(reminderDateTime),
      'repeat': repeat.name,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': iso(completedAt),
      'sortOrder': sortOrder,
    };
  }

  /// A task counts as "in My Day" only if it was added today.
  /// Stale My Day flags are cleaned up by the database layer on startup.
  bool get isInMyDayToday {
    if (!myDay || myDayDate == null) return false;
    final now = DateTime.now();
    return myDayDate!.year == now.year &&
        myDayDate!.month == now.month &&
        myDayDate!.day == now.day;
  }

  bool get isOverdue {
    if (dueDate == null || completed) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }
}
