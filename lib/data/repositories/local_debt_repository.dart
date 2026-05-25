import 'package:drift/drift.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/debt_line_item.dart';
import 'package:listapay/domain/entities/debt_payment.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/debt_status.dart';
import 'package:listapay/domain/entities/payment_method.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';

class LocalDebtRepository implements DebtRepository {
  LocalDebtRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> refreshOverdueStatuses() async {
    final startOfToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    await (_db.update(_db.debts)..where(
          (d) =>
              d.status.equals('pending') &
              d.dueDate.isSmallerThanValue(startOfToday),
        ))
        .write(const DebtsCompanion(status: Value('overdue')));
  }

  @override
  Stream<List<DebtRecord>> watchDebts({DebtStatus? filter}) {
    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ]);

    if (filter != null && filter != DebtStatus.pending) {
      if (filter == DebtStatus.paid) {
        query.where(_db.debts.status.equals('paid'));
      } else if (filter == DebtStatus.overdue) {
        query.where(
          _db.debts.status.isNotIn(['paid']) &
              _db.debts.dueDate.isSmallerThanValue(_startOfToday()),
        );
      }
    } else if (filter == DebtStatus.pending) {
      query.where(
        _db.debts.status.equals('pending') &
            _db.debts.dueDate.isBiggerOrEqualValue(_startOfToday()),
      );
    }

    query.orderBy([OrderingTerm.desc(_db.debts.createdAt)]);

    return query.watch().asyncMap((rows) async {
      await refreshOverdueStatuses();
      final records = await Future.wait(rows.map(_mapDebtRow));
      if (filter == null) {
        return records.where((d) => !d.isFullyPaid).toList();
      }
      if (filter == DebtStatus.overdue) {
        return records
            .where(
              (d) => d.displayStatus == DebtStatus.overdue && !d.isFullyPaid,
            )
            .toList();
      }
      if (filter == DebtStatus.pending) {
        return records
            .where((d) => d.displayStatus == DebtStatus.pending)
            .toList();
      }
      return records;
    });
  }

  @override
  Future<DebtRecord?> getDebt(int id) async {
    await refreshOverdueStatuses();

    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ])..where(_db.debts.id.equals(id));

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapDebtRow(rows.first);
  }

  @override
  Future<void> recordPayment({
    required int debtId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw const DebtException('Payment amount must be greater than zero.');
    }

    final debt = await getDebt(debtId);
    if (debt == null) {
      throw const DebtException('Debt not found.');
    }
    if (debt.isFullyPaid) {
      throw const DebtException('This debt is already paid.');
    }
    if (amount > debt.remaining + 0.001) {
      throw DebtException(
        'Payment exceeds remaining balance (${debt.remaining.toStringAsFixed(2)}).',
      );
    }

    await _db.transaction(() async {
      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              debtId: debtId,
              amount: amount,
              synced: const Value(false),
            ),
          );

      final newPaid = debt.paidAmount + amount;
      if (newPaid >= debt.amount - 0.001) {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
          const DebtsCompanion(status: Value('paid'), synced: Value(false)),
        );
      } else {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
          DebtsCompanion(
            status: Value(
              debt.displayStatus == DebtStatus.overdue ? 'overdue' : 'pending',
            ),
            synced: const Value(false),
          ),
        );
      }
    });
  }

  @override
  Future<void> markAsPaid(int debtId) async {
    final debt = await getDebt(debtId);
    if (debt == null) {
      throw const DebtException('Debt not found.');
    }
    if (debt.isFullyPaid) return;

    await recordPayment(debtId: debtId, amount: debt.remaining);
  }

  Future<DebtRecord> _mapDebtRow(TypedResult row) async {
    final debt = row.readTable(_db.debts);
    final customer = row.readTable(_db.customers);

    final paymentRows =
        await (_db.select(_db.payments)
              ..where((p) => p.debtId.equals(debt.id))
              ..orderBy([(p) => OrderingTerm.desc(p.paidAt)]))
            .get();

    final payments = paymentRows
        .map(
          (p) => DebtPayment(
            id: p.id,
            debtId: p.debtId,
            amount: p.amount,
            paidAt: p.paidAt,
          ),
        )
        .toList();

    final saleId = debt.saleId ?? await _findLinkedSaleId(debt);
    final items = saleId == null
        ? const <DebtLineItem>[]
        : await _loadDebtItems(saleId);
    final paidAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);

    return DebtRecord(
      id: debt.id,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phone,
      saleId: saleId,
      amount: debt.amount,
      paidAmount: paidAmount,
      dueDate: debt.dueDate,
      status: DebtStatus.fromValue(debt.status),
      createdAt: debt.createdAt,
      items: items,
      payments: payments,
    );
  }

  Future<int?> _findLinkedSaleId(Debt debt) async {
    final candidates =
        await (_db.select(_db.sales)
              ..where((s) => s.customerId.equals(debt.customerId))
              ..where((s) => s.paymentMethod.equals(PaymentMethod.utang.value))
              ..where(
                (s) => s.total.isBetweenValues(
                  debt.amount - 0.001,
                  debt.amount + 0.001,
                ),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();

    if (candidates.isEmpty) return null;

    final matchedSale = candidates.reduce((best, current) {
      final bestDiff = best.createdAt.difference(debt.createdAt).abs();
      final currentDiff = current.createdAt.difference(debt.createdAt).abs();
      return currentDiff < bestDiff ? current : best;
    });

    return matchedSale.id;
  }

  Future<List<DebtLineItem>> _loadDebtItems(int saleId) async {
    final rows =
        await (_db.select(_db.saleItems).join([
                innerJoin(
                  _db.products,
                  _db.products.id.equalsExp(_db.saleItems.productId),
                ),
              ])
              ..where(_db.saleItems.saleId.equals(saleId))
              ..orderBy([OrderingTerm.asc(_db.saleItems.id)]))
            .get();

    return rows.map((row) {
      final item = row.readTable(_db.saleItems);
      final product = row.readTable(_db.products);
      return DebtLineItem(
        productId: product.id,
        productName: product.name,
        qty: item.qty,
        unitPrice: item.unitPrice,
        subtotal: item.subtotal,
      );
    }).toList();
  }

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
