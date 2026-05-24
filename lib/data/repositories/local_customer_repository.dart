import 'package:drift/drift.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/data/services/sync_enqueue.dart';
import 'package:listapay/domain/entities/customer.dart' as entities;
import 'package:listapay/domain/entities/customer_summary.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';

class LocalCustomerRepository implements CustomerRepository {
  LocalCustomerRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<entities.Customer>> watchCustomers({String? search}) {
    final query = _db.select(_db.customers);
    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      query.where(
        (c) =>
            c.name.like(term) | c.phone.like(term) | c.address.like(term),
      );
    }
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch().map((rows) => rows.map(_mapCustomer).toList());
  }

  @override
  Future<entities.Customer?> getCustomer(int id) async {
    final row = await (_db.select(_db.customers)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapCustomer(row);
  }

  @override
  Future<int> saveCustomer({
    int? id,
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CustomerException('Customer name is required.');
    }

    final companion = CustomersCompanion(
      name: Value(trimmed),
      phone: Value(_trimOrNull(phone)),
      address: Value(_trimOrNull(address)),
      notes: Value(_trimOrNull(notes)),
      syncedAt: const Value(null),
    );

    if (id == null) {
      return _db.into(_db.customers).insert(companion);
    }

    await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(companion);
    return id;
  }

  @override
  Future<void> deleteCustomer(int id) async {
    final activeDebts = await (_db.select(_db.debts)
          ..where(
            (d) =>
                d.customerId.equals(id) &
                d.status.isNotIn(['paid']),
          ))
        .get();

    if (activeDebts.isNotEmpty) {
      throw const CustomerException(
        'Cannot delete — customer has unpaid debts.',
      );
    }

    await enqueueSyncDelete(_db, entityTable: 'customers', localId: id);
    await (_db.delete(_db.customers)..where((c) => c.id.equals(id))).go();
  }

  @override
  Future<List<CustomerSummary>> getCustomerSummaries() async {
    final rows = await (_db.select(_db.customers)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
    return rows
        .map((c) => CustomerSummary(id: c.id, name: c.name, phone: c.phone))
        .toList();
  }

  entities.Customer _mapCustomer(Customer row) {
    return entities.Customer(
      id: row.id,
      name: row.name,
      phone: row.phone,
      address: row.address,
      notes: row.notes,
    );
  }

  String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
