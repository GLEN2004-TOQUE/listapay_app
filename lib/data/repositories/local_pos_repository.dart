import 'package:drift/drift.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/cart_line.dart';
import 'package:listapay/domain/entities/completed_sale.dart';
import 'package:listapay/domain/entities/customer_summary.dart';
import 'package:listapay/domain/entities/payment_method.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';
import 'package:listapay/domain/repositories/pos_repository.dart';

class LocalPosRepository implements PosRepository {
  LocalPosRepository(this._db, this._customers);

  final AppDatabase _db;
  final CustomerRepository _customers;

  @override
  Future<List<CustomerSummary>> getCustomers() =>
      _customers.getCustomerSummaries();

  @override
  Future<CustomerSummary> createCustomer({
    required String name,
    String? phone,
  }) async {
    final id = await _customers.saveCustomer(name: name, phone: phone);
    final customer = await _customers.getCustomer(id);
    return customer!.summary;
  }

  @override
  Future<CompletedSale> completeSale({
    required int userId,
    required List<CartLine> lines,
    required PaymentMethod paymentMethod,
    double? amountPaid,
    int? customerId,
    DateTime? debtDueDate,
  }) async {
    if (lines.isEmpty) {
      throw const PosException('Cart is empty.');
    }

    if (paymentMethod.requiresCustomer && customerId == null) {
      throw const PosException('Select a customer for Utang payment.');
    }

    final total = lines.fold<double>(0, (sum, line) => sum + line.subtotal);
    if (paymentMethod == PaymentMethod.cash) {
      if (amountPaid == null || amountPaid <= 0) {
        throw const PosException('Enter the amount paid by the customer.');
      }
      if (amountPaid < total) {
        throw const PosException('Amount paid is less than the sale total.');
      }
    }

    final normalizedAmountPaid = switch (paymentMethod) {
      PaymentMethod.cash => amountPaid ?? 0,
      PaymentMethod.utang => 0.0,
      _ => total,
    };
    final changeAmount = paymentMethod == PaymentMethod.cash
        ? normalizedAmountPaid - total
        : 0.0;

    String? customerName;
    if (customerId != null) {
      final customer = await _customers.getCustomer(customerId);
      customerName = customer?.name;
    }

    final lowStockNames = <String>[];

    final saleId = await _db.transaction(() async {
      for (final line in lines) {
        final product = await (_db.select(
          _db.products,
        )..where((p) => p.id.equals(line.productId))).getSingleOrNull();

        if (product == null) {
          throw PosException('Product "${line.name}" no longer exists.');
        }
        if (product.stockQty < line.qty) {
          throw PosException(
            'Not enough stock for ${line.name} (only ${product.stockQty} left).',
          );
        }
      }

      final id = await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              userId: userId,
              customerId: Value(customerId),
              total: total,
              amountPaid: Value(normalizedAmountPaid),
              changeAmount: Value(changeAmount),
              paymentMethod: paymentMethod.value,
              synced: const Value(false),
            ),
          );

      for (final line in lines) {
        await _db
            .into(_db.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                saleId: id,
                productId: line.productId,
                qty: line.qty,
                unitPrice: line.unitPrice,
                subtotal: line.subtotal,
              ),
            );

        final product = await (_db.select(
          _db.products,
        )..where((p) => p.id.equals(line.productId))).getSingle();

        final newStock = product.stockQty - line.qty;
        await (_db.update(_db.products)
              ..where((p) => p.id.equals(line.productId)))
            .write(ProductsCompanion(stockQty: Value(newStock)));

        if (newStock <= product.lowStockThreshold) {
          lowStockNames.add(product.name);
        }
      }

      if (paymentMethod == PaymentMethod.utang && customerId != null) {
        final due = debtDueDate ?? DateTime.now().add(const Duration(days: 30));
        await _db
            .into(_db.debts)
            .insert(
              DebtsCompanion.insert(
                customerId: customerId,
                saleId: Value(id),
                amount: total,
                dueDate: due,
                createdBy: userId,
                synced: const Value(false),
              ),
            );
      }

      return id;
    });

    return CompletedSale(
      saleId: saleId,
      total: total,
      amountPaid: normalizedAmountPaid,
      changeAmount: changeAmount,
      paymentMethod: paymentMethod,
      lines: lines,
      createdAt: DateTime.now(),
      customerName: customerName,
      lowStockProductNames: lowStockNames.toSet().toList(),
    );
  }
}
