import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart' hide Column, Table;
import 'package:uuid/uuid.dart';
import 'app_config.dart';
import 'services/powersync_service.dart';
import 'models/todo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  // NOTE: You must provide valid URL and Key in lib/app_config.dart
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // 2. Initialize PowerSync
  await openPowerSyncDatabase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerSync Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controller for the new task input
  final TextEditingController _controller = TextEditingController();
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  // Helper to sign in so we have a token for PowerSync
  Future<void> _signInAnonymously() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        print('Error signing in: $e');
        // If auth fails (e.g. invalid keys), the app will still work offline
        // but won't sync.
      }
    }
  }

  // Add a new Todo to the local database
  Future<void> _addTodo() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // We generate a UUID locally for the ID
    final newId = uuid.v4(); 
    
    // Insert into local SQLite DB
    // PowerSync will automatically queue this for upload
    await db.execute(
      'INSERT INTO todos (id, task, completed, created_at) VALUES (?, ?, ?, ?)',
      [newId, text, 0, DateTime.now().toIso8601String()],
    );

    _controller.clear();
  }

  // Toggle completion status
  Future<void> _toggleTodo(Todo todo) async {
    await db.execute(
      'UPDATE todos SET completed = ? WHERE id = ?',
      [todo.completed ? 0 : 1, todo.id],
    );
  }

  // Delete a todo
  Future<void> _deleteTodo(String id) async {
    await db.execute('DELETE FROM todos WHERE id = ?', [id]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerSync Todos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Status indicator
          StreamBuilder<SyncStatus>(
            stream: db.statusStream,
            builder: (context, snapshot) {
              final status = snapshot.data;
              final connected = status?.connected ?? false;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Icon(
                  connected ? Icons.cloud_done : Icons.cloud_off,
                  color: connected ? Colors.green : Colors.grey,
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Input Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter a new task',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          
          // List Area
          Expanded(
            child: StreamBuilder<List<Todo>>(
              // Watch the query - updates automatically when DB changes
              stream: db.watch(
                'SELECT * FROM todos ORDER BY created_at DESC'
              ).map((results) {
                // Convert ResultSet (List of Rows) to List<Todo>
                return results.map((row) => Todo.fromMap(Map<String, dynamic>.from(row))).toList();
              }),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todos = snapshot.data!;
                
                if (todos.isEmpty) {
                  return const Center(
                    child: Text('No tasks yet. Add one above!'),
                  );
                }

                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return ListTile(
                      leading: Checkbox(
                        value: todo.completed,
                        onChanged: (_) => _toggleTodo(todo),
                      ),
                      title: Text(
                        todo.task,
                        style: TextStyle(
                          decoration: todo.completed 
                            ? TextDecoration.lineThrough 
                            : null,
                          color: todo.completed ? Colors.grey : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTodo(todo.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
