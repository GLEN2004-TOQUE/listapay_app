import 'package:ListaPay/domain/entities/debt_record.dart';
import 'package:ListaPay/domain/entities/debt_status.dart';

class DebtException implements Exception {
  const DebtException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class DebtRepository {
  Future<void> refreshOverdueStatuses();

  Stream<List<DebtRecord>> watchDebts({DebtStatus? filter});

  Future<DebtRecord?> getDebt(int id);

  Future<void> updateDebt({
    required int debtId,
    required int customerId,
    required DateTime dueDate,
  });

  Future<void> recordCustomerPayment({
    required int customerId,
    required double amount,
  });

  Future<void> recordPayment({
    required int debtId,
    required double amount,
  });

  Future<void> markAsPaid(int debtId);

  Future<void> deleteDebt(int debtId);
}
