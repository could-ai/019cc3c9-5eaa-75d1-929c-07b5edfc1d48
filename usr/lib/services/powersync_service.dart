import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../models/todo.dart'; // Access to schema

/// This class handles the connection between the local PowerSync SQLite DB
/// and the upstream Supabase backend.
class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // 1. Get the Supabase session
    final session = supabase.auth.currentSession;
    if (session == null) {
      // Not logged in
      return null;
    }

    // 2. Use the access token to authenticate with PowerSync
    // Note: In a production app, you might fetch a specific PowerSync token
    // from your backend (Edge Function) if you are using custom auth.
    // For standard setups, the Supabase JWT often works if configured in PowerSync.
    final token = session.accessToken;

    return PowerSyncCredentials(
      endpoint: AppConfig.powerSyncUrl,
      token: token,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // This method is called when there are local changes to push upstream.
    // PowerSync queues the writes in an 'upload queue'.
    
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (var op in transaction.crud) {
        final table = op.table;
        final id = op.id;

        // Map the operations to Supabase calls
        if (op.op == UpdateType.put) {
          // Insert or Update
          // We use 'upsert' in Supabase to handle both
          var data = Map<String, dynamic>.from(op.opData!);
          data['id'] = id; // Ensure ID is included
          
          await supabase.from(table).upsert(data);
        } else if (op.op == UpdateType.patch) {
          // Partial Update
          await supabase.from(table).update(op.opData!).eq('id', id);
        } else if (op.op == UpdateType.delete) {
          // Delete
          await supabase.from(table).delete().eq('id', id);
        }
      }

      // Mark the transaction as complete in the local queue
      await transaction.complete();
      
    } catch (e) {
      // If upload fails, we don't complete the transaction.
      // PowerSync will retry later.
      print('Upload failed: $e');
      rethrow;
    }
  }
}

// Global instance
late final PowerSyncDatabase db;

Future<void> openPowerSyncDatabase() async {
  // 1. Initialize the database with the schema
  // The path is managed by the SDK (usually in Application Documents)
  db = PowerSyncDatabase(schema: schema, path: 'powersync_demo.db');

  // 2. Open the database (creates tables if they don't exist)
  await db.initialize();

  // 3. Connect to the backend
  // We only connect if Supabase is initialized (handled in main)
  final connector = SupabaseConnector();
  db.connect(connector: connector);
}
