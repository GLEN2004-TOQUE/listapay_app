import 'package:equatable/equatable.dart';
import 'package:listapay/domain/entities/product_item.dart';

class CartLine extends Equatable {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    required this.maxStock,
  });

  final int productId;
  final String name;
  final double unitPrice;
  final int qty;
  final int maxStock;

  double get subtotal => unitPrice * qty;

  bool get canIncrease => qty < maxStock;

  CartLine copyWith({int? qty}) {
    return CartLine(
      productId: productId,
      name: name,
      unitPrice: unitPrice,
      qty: qty ?? this.qty,
      maxStock: maxStock,
    );
  }

  factory CartLine.fromProduct(ProductItem product, {int qty = 1}) {
    return CartLine(
      productId: product.id,
      name: product.name,
      unitPrice: product.price,
      qty: qty,
      maxStock: product.stockQty,
    );
  }

  @override
  List<Object?> get props => [productId, name, unitPrice, qty, maxStock];
}
