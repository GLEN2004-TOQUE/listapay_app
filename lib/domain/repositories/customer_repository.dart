import 'package:listapay/domain/entities/customer.dart';
import 'package:listapay/domain/entities/customer_summary.dart';

class CustomerException implements Exception {
  const CustomerException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class CustomerRepository {
  Stream<List<Customer>> watchCustomers({String? search});

  Future<Customer?> getCustomer(int id);

  Future<int> saveCustomer({
    int? id,
    required String name,
    String? phone,
    String? address,
    String? notes,
  });

  Future<void> deleteCustomer(int id);

  Future<List<CustomerSummary>> getCustomerSummaries();
}
