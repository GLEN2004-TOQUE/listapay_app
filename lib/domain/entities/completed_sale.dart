import 'package:equatable/equatable.dart';
import 'package:listapay/domain/entities/cart_line.dart';
import 'package:listapay/domain/entities/payment_method.dart';

class CompletedSale extends Equatable {
  const CompletedSale({
    required this.saleId,
    required this.total,
    required this.paymentMethod,
    required this.lines,
    required this.createdAt,
    this.customerName,
    this.lowStockProductNames = const [],
  });

  final int saleId;
  final double total;
  final PaymentMethod paymentMethod;
  final List<CartLine> lines;
  final DateTime createdAt;
  final String? customerName;
  final List<String> lowStockProductNames;

  @override
  List<Object?> get props => [
        saleId,
        total,
        paymentMethod,
        lines,
        createdAt,
        customerName,
        lowStockProductNames,
      ];
}
