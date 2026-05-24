import 'package:listapay/data/database/app_database.dart';

/// Enqueues a delete for the cloud sync engine (PIN stays local).
Future<void> enqueueSyncDelete(
  AppDatabase db, {
  required String entityTable,
  required int localId,
}) async {
  await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityTable: entityTable,
          recordId: localId.toString(),
          operation: 'delete',
          payloadJson: '{}',
        ),
      );
}
