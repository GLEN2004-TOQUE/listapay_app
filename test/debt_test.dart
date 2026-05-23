import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/debt_status.dart';

void main() {
  test('DebtRecord remaining balance', () {
    final debt = DebtRecord(
      id: 1,
      customerId: 1,
      customerName: 'Juan',
      amount: 1000,
      paidAmount: 400,
      dueDate: DateTime.now().add(const Duration(days: 10)),
      status: DebtStatus.pending,
      createdAt: DateTime.now(),
    );
    expect(debt.remaining, 600);
    expect(debt.isFullyPaid, isFalse);
  });

  test('DebtRecord displayStatus is overdue after due date', () {
    final debt = DebtRecord(
      id: 1,
      customerId: 1,
      customerName: 'Juan',
      amount: 500,
      paidAmount: 0,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      status: DebtStatus.pending,
      createdAt: DateTime.now(),
    );
    expect(debt.displayStatus, DebtStatus.overdue);
  });

  test('DebtRecord isDueSoon within 3 days', () {
    final debt = DebtRecord(
      id: 1,
      customerId: 1,
      customerName: 'Juan',
      amount: 500,
      paidAmount: 0,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      status: DebtStatus.pending,
      createdAt: DateTime.now(),
    );
    expect(debt.isDueSoon, isTrue);
  });
}
