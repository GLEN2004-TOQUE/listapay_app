import 'package:equatable/equatable.dart';

class DebtPayment extends Equatable {
  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
  });

  final int id;
  final int debtId;
  final double amount;
  final DateTime paidAt;

  @override
  List<Object?> get props => [id, debtId, amount, paidAt];
}
