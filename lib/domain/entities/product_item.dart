import 'package:equatable/equatable.dart';

class ProductItem extends Equatable {
  const ProductItem({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    required this.price,
    required this.cost,
    required this.stockQty,
    required this.lowStockThreshold,
  });

  final int id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final double price;
  final double cost;
  final int stockQty;
  final int lowStockThreshold;

  bool get isLowStock => stockQty <= lowStockThreshold;

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        categoryId,
        categoryName,
        categoryColor,
        price,
        cost,
        stockQty,
        lowStockThreshold,
      ];
}
