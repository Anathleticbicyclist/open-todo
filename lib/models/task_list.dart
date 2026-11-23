/// Data model for a task list (both smart lists and user lists).
class TaskList {
  final int? id;
  final String name;
  final String colorHex; // e.g. '#0078D4'
  final bool isSmart;
  final DateTime createdAt;

  const TaskList({
    this.id,
    required this.name,
    required this.colorHex,
    required this.isSmart,
    required this.createdAt,
  });

  TaskList copyWith({
    int? id,
    String? name,
    String? colorHex,
    bool? isSmart,
    DateTime? createdAt,
  }) {
    return TaskList(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isSmart: isSmart ?? this.isSmart,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TaskList.fromMap(Map<String, dynamic> map) {
    return TaskList(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorHex: map['color'] as String,
      isSmart: (map['isSmart'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': colorHex,
      'isSmart': isSmart ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Smart-list ids are fixed so the UI can refer to them directly.
  static const int myDayId = 1;
  static const int importantId = 2;
  static const int plannedId = 3;
  static const int allTasksId = 4;
  static const int defaultListId = 5;

  static bool isSmartId(int id) => id >= 1 && id <= 4;

  /// The colour palette offered when creating / editing a list.
  static const List<String> palette = [
    '#0078D4', // Microsoft blue
    '#038387', // teal
    '#498205', // green
    '#A4262C', // red
    '#8764B8', // purple
    '#CA5010', // orange
    '#881798', // magenta
    '#038387',
    '#69797E', // grey
    '#E81123', // bright red
  ];
}
