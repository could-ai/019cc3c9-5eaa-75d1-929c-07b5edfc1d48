import 'package:powersync/powersync.dart';

class Todo {
  final String id;
  final String task;
  final bool completed;

  Todo({
    required this.id,
    required this.task,
    required this.completed,
  });

  factory Todo.fromRow(Row row) {
    return Todo(
      id: row['id'] as String,
      task: row['task'] as String,
      completed: (row['completed'] as int) == 1,
    );
  }
}

// Define the schema for the local SQLite database
// This should match your PowerSync Sync Rules and Supabase Schema
final schema = Schema([
  Table('todos', [
    Column.text('task'),
    Column.integer('completed'), // 0 or 1
    Column.text('created_at'),
  ]),
]);
