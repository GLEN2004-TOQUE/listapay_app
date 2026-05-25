import 'package:equatable/equatable.dart';

class DebtLineItem extends Equatable {
  const DebtLineItem({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
  });

  final int productId;
  final String productName;
  final int qty;
  final double unitPrice;
  final double subtotal;

  @override
  List<Object?> get props => [productId, productName, qty, unitPrice, subtotal];
}
