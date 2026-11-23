import 'package:flutter_test/flutter_test.dart';
import 'package:open_todo/models/step_item.dart';
import 'package:open_todo/models/task_item.dart';
import 'package:open_todo/models/task_list.dart';
import 'package:open_todo/services/import_export.dart';

void main() {
  group('TaskList', () {
    test('round-trips through toMap/fromMap', () {
      final list = TaskList(
        id: 7,
        name: 'Groceries',
        colorHex: '#0078D4',
        isSmart: false,
        createdAt: DateTime(2026, 11, 23, 10, 0),
      );
      final restored = TaskList.fromMap(list.toMap());
      expect(restored.id, 7);
      expect(restored.name, 'Groceries');
      expect(restored.colorHex, '#0078D4');
      expect(restored.isSmart, isFalse);
    });

    test('smart ids are recognised', () {
      expect(TaskList.isSmartId(TaskList.myDayId), isTrue);
      expect(TaskList.isSmartId(TaskList.allTasksId), isTrue);
      expect(TaskList.isSmartId(TaskList.defaultListId), isFalse);
      expect(TaskList.isSmartId(99), isFalse);
    });
  });

  group('TaskItem', () {
    test('round-trips through toMap/fromMap', () {
      final task = TaskItem(
        id: 3,
        listId: 5,
        title: 'Buy milk',
        completed: true,
        important: true,
        myDay: true,
        myDayDate: DateTime(2026, 11, 23),
        dueDate: DateTime(2026, 11, 24),
        reminderDateTime: DateTime(2026, 11, 24, 9, 0),
        repeat: RepeatOption.weekly,
        note: 'Oat milk',
        createdAt: DateTime(2026, 11, 23, 9, 30),
        completedAt: DateTime(2026, 11, 23, 10, 0),
        sortOrder: 1,
      );
      final restored = TaskItem.fromMap(task.toMap());
      expect(restored.id, 3);
      expect(restored.title, 'Buy milk');
      expect(restored.completed, isTrue);
      expect(restored.important, isTrue);
      expect(restored.myDay, isTrue);
      expect(restored.repeat, RepeatOption.weekly);
      expect(restored.note, 'Oat milk');
      expect(restored.dueDate, DateTime(2026, 11, 24));
    });

    test('isOverdue is true only for past due dates on open tasks', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final overdue = TaskItem(
        listId: 5,
        title: 'late',
        dueDate: yesterday,
        createdAt: now,
      );
      final future = TaskItem(
        listId: 5,
        title: 'soon',
        dueDate: tomorrow,
        createdAt: now,
      );
      final done = TaskItem(
        listId: 5,
        title: 'done',
        dueDate: yesterday,
        completed: true,
        createdAt: now,
      );
      expect(overdue.isOverdue, isTrue);
      expect(future.isOverdue, isFalse);
      expect(done.isOverdue, isFalse);
    });

    test('isInMyDayToday only matches today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final inDay = TaskItem(
        listId: 5,
        title: 'today',
        myDay: true,
        myDayDate: today,
        createdAt: now,
      );
      final stale = TaskItem(
        listId: 5,
        title: 'stale',
        myDay: true,
        myDayDate: yesterday,
        createdAt: now,
      );
      expect(inDay.isInMyDayToday, isTrue);
      expect(stale.isInMyDayToday, isFalse);
    });

    test('RepeatOption parses from string and falls back to none', () {
      expect(RepeatOption.fromString('daily'), RepeatOption.daily);
      expect(RepeatOption.fromString('weekdays'), RepeatOption.weekdays);
      expect(RepeatOption.fromString('bogus'), RepeatOption.none);
      expect(RepeatOption.monthly.label, 'Monthly');
    });
  });

  group('StepItem', () {
    test('round-trips through toMap/fromMap', () {
      const step = StepItem(
        id: 2,
        taskId: 3,
        title: 'First step',
        completed: true,
        sortOrder: 0,
      );
      final restored = StepItem.fromMap(step.toMap());
      expect(restored.id, 2);
      expect(restored.taskId, 3);
      expect(restored.title, 'First step');
      expect(restored.completed, isTrue);
    });
  });

  group('ImportExportService helpers', () {
    test('parseCsv handles quoted fields and embedded commas', () {
      const csv =
          'list,title,completed,important,due_date,note\n'
          'Groceries,"Buy milk, oat",false,true,2026-11-24,"Two cartons"\n'
          'Tasks,Call mom,true,false,,\n';
      final rows = ImportExportService.parseCsv(csv);
      expect(rows.length, 3);
      expect(rows[0], ['list', 'title', 'completed', 'important', 'due_date', 'note']);
      expect(rows[1][1], 'Buy milk, oat');
      expect(rows[1][5], 'Two cartons');
      expect(rows[2][1], 'Call mom');
    });

    test('stripHtml converts Graph HTML bodies to plain text', () {
      const html =
          '<p>Pick up the parcel</p><p>Second line<br>with a break</p>';
      final text = ImportExportService.stripHtml(html);
      expect(text, contains('Pick up the parcel'));
      expect(text, contains('Second line'));
      expect(text.contains('<'), isFalse);
    });
  });
}
