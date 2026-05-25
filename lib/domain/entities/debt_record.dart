import 'package:equatable/equatable.dart';
import 'package:listapay/domain/entities/debt_line_item.dart';
import 'package:listapay/domain/entities/debt_payment.dart';
import 'package:listapay/domain/entities/debt_status.dart';
import 'package:listapay/core/utils/ph_time.dart';

class DebtRecord extends Equatable {
  const DebtRecord({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.saleId,
    required this.amount,
    required this.paidAmount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.payments = const [],
  });

  final int id;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final int? saleId;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final DebtStatus status;
  final DateTime createdAt;
  final List<DebtLineItem> items;
  final List<DebtPayment> payments;

  double get remaining => (amount - paidAmount).clamp(0, amount);

  bool get isFullyPaid => status == DebtStatus.paid || remaining <= 0;

  DebtStatus get displayStatus {
    if (isFullyPaid) return DebtStatus.paid;
    final dueDay = PhTime.startOfDay(dueDate);
    final nowDay = PhTime.today();
    if (nowDay.isAfter(dueDay)) return DebtStatus.overdue;
    return DebtStatus.pending;
  }

  bool get isDueSoon {
    if (isFullyPaid) return false;
    final days = PhTime.startOfDay(dueDate).difference(PhTime.today()).inDays;
    return days >= 0 && days <= 3;
  }

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    customerPhone,
    saleId,
    amount,
    paidAmount,
    dueDate,
    status,
    createdAt,
    items,
    payments,
  ];
}
