import 'package:drift/drift.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/data/services/store_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncResult {
  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.deleted = 0,
    this.skipped = false,
    this.message,
  });

  final int pushed;
  final int pulled;
  final int deleted;
  final bool skipped;
  final String? message;

  bool get ok => message == null && !skipped;
}

/// Offline-first push/pull sync against Supabase (PIN auth stays local).
class SyncService {
  SyncService(this._db, this._storeSession, this._connectivity);

  final AppDatabase _db;
  final StoreSessionService _storeSession;
  final ConnectivityService _connectivity;

  static const _lastPullKey = 'last_pull_at';

  SupabaseClient get _client => Supabase.instance.client;

  Future<SyncResult> syncNow() async {
    if (!await _connectivity.isOnline()) {
      return const SyncResult(skipped: true, message: 'Offline');
    }

    final session = await _storeSession.getSession();
    if (session == null) {
      return const SyncResult(skipped: true, message: 'Not paired to a store');
    }

    await _storeSession.ensureSupabaseAuth();
    await _storeSession.restoreSessionIfNeeded();

    final jwtStoreId = _client.auth.currentSession?.user.appMetadata['store_id']
        ?.toString();
    if (jwtStoreId != session.storeId) {
      return const SyncResult(
        skipped: true,
        message: 'Cloud session expired — pair again in Settings',
      );
    }

    try {
      final pushed = await _pushAll(session.storeId);
      final deleted = await _processDeleteQueue(session.storeId);
      final pulled = await _pullAll(session.storeId);
      return SyncResult(pushed: pushed, pulled: pulled, deleted: deleted);
    } on PostgrestException catch (e) {
      return SyncResult(message: e.message);
    } catch (e) {
      return SyncResult(message: e.toString());
    }
  }

  Future<int> _pushAll(String storeId) async {
    var count = 0;
    count += await _pushCategories(storeId);
    count += await _pushProducts(storeId);
    count += await _pushCustomers(storeId);
    count += await _pushSales(storeId);
    count += await _pushDebts(storeId);
    count += await _pushPayments(storeId);
    return count;
  }

  Future<int> _pushCategories(String storeId) async {
    final rows = await (_db.select(
      _db.categories,
    )..where((c) => c.syncedAt.isNull())).get();
    if (rows.isEmpty) return 0;

    final payload = rows
        .map(
          (r) => {
            'store_id': storeId,
            'local_id': r.id,
            'name': r.name,
            'color': r.color,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();

    await _client
        .from('categories')
        .upsert(payload, onConflict: 'store_id,local_id');

    final ids = rows.map((r) => r.id).toList();
    await (_db.update(_db.categories)..where((c) => c.id.isIn(ids))).write(
      CategoriesCompanion(syncedAt: Value(DateTime.now())),
    );
    return rows.length;
  }

  Future<int> _pushProducts(String storeId) async {
    final rows = await (_db.select(
      _db.products,
    )..where((p) => p.syncedAt.isNull())).get();
    if (rows.isEmpty) return 0;

    final payload = rows
        .map(
          (r) => {
            'store_id': storeId,
            'local_id': r.id,
            'name': r.name,
            'barcode': r.barcode,
            'category_local_id': r.categoryId,
            'price': r.price,
            'cost': r.cost,
            'stock_qty': r.stockQty,
            'low_stock_threshold': r.lowStockThreshold,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();

    await _client
        .from('products')
        .upsert(payload, onConflict: 'store_id,local_id');

    final ids = rows.map((r) => r.id).toList();
    await (_db.update(_db.products)..where((p) => p.id.isIn(ids))).write(
      ProductsCompanion(syncedAt: Value(DateTime.now())),
    );
    return rows.length;
  }

  Future<int> _pushCustomers(String storeId) async {
    final rows = await (_db.select(
      _db.customers,
    )..where((c) => c.syncedAt.isNull())).get();
    if (rows.isEmpty) return 0;

    final payload = rows
        .map(
          (r) => {
            'store_id': storeId,
            'local_id': r.id,
            'name': r.name,
            'phone': r.phone,
            'address': r.address,
            'notes': r.notes,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();

    await _client
        .from('customers')
        .upsert(payload, onConflict: 'store_id,local_id');

    final ids = rows.map((r) => r.id).toList();
    await (_db.update(_db.customers)..where((c) => c.id.isIn(ids))).write(
      CustomersCompanion(syncedAt: Value(DateTime.now())),
    );
    return rows.length;
  }

  Future<int> _pushSales(String storeId) async {
    final sales = await (_db.select(
      _db.sales,
    )..where((s) => s.synced.equals(false))).get();
    if (sales.isEmpty) return 0;

    var count = 0;
    for (final sale in sales) {
      final items = await (_db.select(
        _db.saleItems,
      )..where((i) => i.saleId.equals(sale.id))).get();

      await _client.from('sales').upsert({
        'store_id': storeId,
        'local_id': sale.id,
        'customer_local_id': sale.customerId,
        'user_local_id': sale.userId,
        'total': sale.total,
        'payment_method': sale.paymentMethod,
        'status': sale.status,
        'created_at': sale.createdAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'store_id,local_id');

      if (items.isNotEmpty) {
        await _client
            .from('sale_items')
            .upsert(
              items
                  .map(
                    (i) => {
                      'store_id': storeId,
                      'local_id': i.id,
                      'sale_local_id': i.saleId,
                      'product_local_id': i.productId,
                      'qty': i.qty,
                      'unit_price': i.unitPrice,
                      'subtotal': i.subtotal,
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    },
                  )
                  .toList(),
              onConflict: 'store_id,local_id',
            );
      }

      await (_db.update(_db.sales)..where((s) => s.id.equals(sale.id))).write(
        const SalesCompanion(synced: Value(true)),
      );
      count++;
    }
    return count;
  }

  Future<int> _pushDebts(String storeId) async {
    final rows = await (_db.select(
      _db.debts,
    )..where((d) => d.synced.equals(false))).get();
    if (rows.isEmpty) return 0;

    await _client
        .from('debts')
        .upsert(
          rows
              .map(
                (r) => {
                  'store_id': storeId,
                  'local_id': r.id,
                  'customer_local_id': r.customerId,
                  'amount': r.amount,
                  'interest_rate': r.interestRate,
                  'due_date': r.dueDate.toUtc().toIso8601String(),
                  'status': r.status,
                  'created_by_local_id': r.createdBy,
                  'created_at': r.createdAt.toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                },
              )
              .toList(),
          onConflict: 'store_id,local_id',
        );

    final ids = rows.map((r) => r.id).toList();
    await (_db.update(_db.debts)..where((d) => d.id.isIn(ids))).write(
      const DebtsCompanion(synced: Value(true)),
    );
    return rows.length;
  }

  Future<int> _pushPayments(String storeId) async {
    final rows = await (_db.select(
      _db.payments,
    )..where((p) => p.synced.equals(false))).get();
    if (rows.isEmpty) return 0;

    await _client
        .from('payments')
        .upsert(
          rows
              .map(
                (r) => {
                  'store_id': storeId,
                  'local_id': r.id,
                  'debt_local_id': r.debtId,
                  'amount': r.amount,
                  'paid_at': r.paidAt.toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                },
              )
              .toList(),
          onConflict: 'store_id,local_id',
        );

    final ids = rows.map((r) => r.id).toList();
    await (_db.update(_db.payments)..where((p) => p.id.isIn(ids))).write(
      const PaymentsCompanion(synced: Value(true)),
    );
    return rows.length;
  }

  Future<int> _processDeleteQueue(String storeId) async {
    final rows =
        await (_db.select(_db.syncQueue)
              ..where((q) => q.operation.equals('delete'))
              ..where((q) => q.entityTable.isNotIn(['sms', 'notification'])))
            .get();

    var count = 0;
    for (final row in rows) {
      final table = row.entityTable;
      if (!_isSyncTable(table)) continue;

      final localId = int.tryParse(row.recordId);
      if (localId == null) continue;

      await _client
          .from(table)
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('store_id', storeId)
          .eq('local_id', localId);

      await (_db.delete(_db.syncQueue)..where((q) => q.id.equals(row.id))).go();
      count++;
    }
    return count;
  }

  bool _isSyncTable(String table) {
    return const {
      'categories',
      'products',
      'customers',
      'sales',
      'sale_items',
      'debts',
      'payments',
    }.contains(table);
  }

  Future<int> _pullAll(String storeId) async {
    final since = await _readLastPull();
    var count = 0;
    count += await _pullTable(
      table: 'categories',
      storeId: storeId,
      since: since,
      apply: _applyCategory,
    );
    count += await _pullTable(
      table: 'products',
      storeId: storeId,
      since: since,
      apply: _applyProduct,
    );
    count += await _pullTable(
      table: 'customers',
      storeId: storeId,
      since: since,
      apply: _applyCustomer,
    );
    count += await _pullTable(
      table: 'debts',
      storeId: storeId,
      since: since,
      apply: _applyDebt,
    );
    count += await _pullTable(
      table: 'payments',
      storeId: storeId,
      since: since,
      apply: _applyPayment,
    );
    await _writeLastPull(DateTime.now().toUtc());
    return count;
  }

  Future<int> _pullTable({
    required String table,
    required String storeId,
    required DateTime? since,
    required Future<void> Function(Map<String, dynamic> row) apply,
  }) async {
    var query = _client.from(table).select().eq('store_id', storeId);
    if (since != null) {
      query = query.gt('updated_at', since.toIso8601String());
    }

    final rows = await query as List<dynamic>;

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      await apply(row);
    }
    return rows.length;
  }

  Future<DateTime?> _readLastPull() async {
    final row = await (_db.select(
      _db.syncMeta,
    )..where((m) => m.key.equals(_lastPullKey))).getSingleOrNull();
    if (row?.value == null) return null;
    return DateTime.tryParse(row!.value!);
  }

  Future<void> _writeLastPull(DateTime at) async {
    await _db
        .into(_db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            key: _lastPullKey,
            value: Value(at.toIso8601String()),
          ),
        );
  }

  Future<void> _applyCategory(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) {
      final localId = row['local_id'] as int;
      await (_db.delete(
        _db.categories,
      )..where((c) => c.id.equals(localId))).go();
      return;
    }

    final localId = row['local_id'] as int;
    final existing = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(localId))).getSingleOrNull();

    final companion = CategoriesCompanion(
      id: Value(localId),
      name: Value(row['name'] as String),
      color: Value(row['color'] as String? ?? '#0D7C4E'),
      syncedAt: Value(DateTime.now()),
    );

    if (existing == null) {
      await _db.into(_db.categories).insert(companion);
    } else {
      await (_db.update(
        _db.categories,
      )..where((c) => c.id.equals(localId))).write(companion);
    }
  }

  Future<void> _applyProduct(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) {
      final localId = row['local_id'] as int;
      await (_db.delete(_db.products)..where((p) => p.id.equals(localId))).go();
      return;
    }

    final localId = row['local_id'] as int;
    final existing = await (_db.select(
      _db.products,
    )..where((p) => p.id.equals(localId))).getSingleOrNull();

    final companion = ProductsCompanion(
      id: Value(localId),
      name: Value(row['name'] as String),
      barcode: Value(row['barcode'] as String?),
      categoryId: Value(row['category_local_id'] as int?),
      price: Value((row['price'] as num).toDouble()),
      cost: Value((row['cost'] as num?)?.toDouble() ?? 0),
      stockQty: Value(row['stock_qty'] as int? ?? 0),
      lowStockThreshold: Value(row['low_stock_threshold'] as int? ?? 5),
      syncedAt: Value(DateTime.now()),
    );

    if (existing == null) {
      await _db.into(_db.products).insert(companion);
    } else {
      await (_db.update(
        _db.products,
      )..where((p) => p.id.equals(localId))).write(companion);
    }
  }

  Future<void> _applyCustomer(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) {
      final localId = row['local_id'] as int;
      await (_db.delete(
        _db.customers,
      )..where((c) => c.id.equals(localId))).go();
      return;
    }

    final localId = row['local_id'] as int;
    final existing = await (_db.select(
      _db.customers,
    )..where((c) => c.id.equals(localId))).getSingleOrNull();

    final companion = CustomersCompanion(
      id: Value(localId),
      name: Value(row['name'] as String),
      phone: Value(row['phone'] as String?),
      address: Value(row['address'] as String?),
      notes: Value(row['notes'] as String?),
      syncedAt: Value(DateTime.now()),
    );

    if (existing == null) {
      await _db.into(_db.customers).insert(companion);
    } else {
      await (_db.update(
        _db.customers,
      )..where((c) => c.id.equals(localId))).write(companion);
    }
  }

  Future<void> _applyDebt(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) {
      final localId = row['local_id'] as int;
      await (_db.delete(_db.debts)..where((d) => d.id.equals(localId))).go();
      return;
    }

    final localId = row['local_id'] as int;
    final existing = await (_db.select(
      _db.debts,
    )..where((d) => d.id.equals(localId))).getSingleOrNull();

    final companion = DebtsCompanion(
      id: Value(localId),
      customerId: Value(row['customer_local_id'] as int),
      amount: Value((row['amount'] as num).toDouble()),
      interestRate: Value((row['interest_rate'] as num?)?.toDouble() ?? 0),
      dueDate: Value(DateTime.parse(row['due_date'] as String).toLocal()),
      status: Value(row['status'] as String),
      createdBy: Value(row['created_by_local_id'] as int),
      synced: const Value(true),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
    );

    if (existing == null) {
      await _db.into(_db.debts).insert(companion);
    } else {
      await (_db.update(
        _db.debts,
      )..where((d) => d.id.equals(localId))).write(companion);
    }
  }

  Future<void> _applyPayment(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) {
      final localId = row['local_id'] as int;
      await (_db.delete(_db.payments)..where((p) => p.id.equals(localId))).go();
      return;
    }

    final localId = row['local_id'] as int;
    final existing = await (_db.select(
      _db.payments,
    )..where((p) => p.id.equals(localId))).getSingleOrNull();

    final companion = PaymentsCompanion(
      id: Value(localId),
      debtId: Value(row['debt_local_id'] as int),
      amount: Value((row['amount'] as num).toDouble()),
      paidAt: Value(DateTime.parse(row['paid_at'] as String).toLocal()),
      synced: const Value(true),
    );

    if (existing == null) {
      await _db.into(_db.payments).insert(companion);
    } else {
      await (_db.update(
        _db.payments,
      )..where((p) => p.id.equals(localId))).write(companion);
    }
  }
}
