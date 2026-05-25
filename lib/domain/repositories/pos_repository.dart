import 'package:listapay/domain/entities/cart_line.dart';
import 'package:listapay/domain/entities/completed_sale.dart';
import 'package:listapay/domain/entities/customer_summary.dart';
import 'package:listapay/domain/entities/payment_method.dart';

class PosException implements Exception {
  const PosException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class PosRepository {
  Future<List<CustomerSummary>> getCustomers();

  Future<CustomerSummary> createCustomer({required String name, String? phone});

  Future<CompletedSale> completeSale({
    required int userId,
    required List<CartLine> lines,
    required PaymentMethod paymentMethod,
    double? amountPaid,
    int? customerId,
    DateTime? debtDueDate,
  });
}
