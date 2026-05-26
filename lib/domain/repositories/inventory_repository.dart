import 'package:ListaPay/domain/entities/product_category.dart';
import 'package:ListaPay/domain/entities/product_item.dart';

class InventoryException implements Exception {
  const InventoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class InventoryRepository {
  Future<void> initialize();

  Stream<List<ProductItem>> watchProducts({String? search});

  Future<ProductItem?> getProduct(int id);

  Future<ProductItem?> findByBarcode(String barcode);

  Future<int> saveProduct({
    int? id,
    required String name,
    String? barcode,
    int? categoryId,
    required double price,
    double cost = 0,
    required int stockQty,
    required int lowStockThreshold,
  });

  Future<void> deleteProduct(int id);

  Stream<List<ProductCategory>> watchCategories();

  Future<int> saveCategory({
    int? id,
    required String name,
    required String color,
  });

  Future<void> deleteCategory(int id);
}
