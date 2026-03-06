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

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as String,
      task: map['task'] as String,
      completed: (map['completed'] as int) == 1,
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
