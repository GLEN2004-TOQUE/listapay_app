import 'package:flutter/widgets.dart';
import 'package:listapay/core/config/supabase_config.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/data/services/store_session_service.dart';
import 'package:listapay/data/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

const listapayBackgroundSyncTask = 'listapayBackgroundSync';

/// Registers periodic background sync (Android; iOS requires extra setup).
Future<void> registerBackgroundSync() async {
  if (!SupabaseConfig.isConfigured) return;

  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    listapayBackgroundSyncTask,
    listapayBackgroundSyncTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != listapayBackgroundSyncTask) return false;

    WidgetsFlutterBinding.ensureInitialized();

    if (!SupabaseConfig.isConfigured) return false;

    if (!Supabase.instance.isInitialized) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    }

    final db = AppDatabase();
  try {
      final storeSession = StoreSessionService();
      final connectivity = ConnectivityService();
      final sync = SyncService(
        db: db,
        storeSession: storeSession,
        connectivity: connectivity,
      );
      await storeSession.restoreSessionIfNeeded();
      final result = await sync.syncNow();
      return result.ok || result.skipped;
    } finally {
      await db.close();
    }
  });
}
