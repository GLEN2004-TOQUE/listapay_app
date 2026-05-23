import 'package:equatable/equatable.dart';
import 'package:listapay/domain/entities/debt_payment.dart';
import 'package:listapay/domain/entities/debt_status.dart';

class DebtRecord extends Equatable {
  const DebtRecord({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.amount,
    required this.paidAmount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.payments = const [],
  });

  final int id;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final DebtStatus status;
  final DateTime createdAt;
  final List<DebtPayment> payments;

  double get remaining => (amount - paidAmount).clamp(0, amount);

  bool get isFullyPaid => status == DebtStatus.paid || remaining <= 0;

  DebtStatus get displayStatus {
    if (isFullyPaid) return DebtStatus.paid;
    final today = DateTime.now();
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final nowDay = DateTime(today.year, today.month, today.day);
    if (nowDay.isAfter(dueDay)) return DebtStatus.overdue;
    return DebtStatus.pending;
  }

  bool get isDueSoon {
    if (isFullyPaid) return false;
    final days = dueDate.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 3;
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        amount,
        paidAmount,
        dueDate,
        status,
        createdAt,
        payments,
      ];
}
