import 'package:drift/drift.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/product_category.dart';
import 'package:listapay/domain/entities/product_item.dart';
import 'package:listapay/domain/repositories/inventory_repository.dart';

class LocalInventoryRepository implements InventoryRepository {
  LocalInventoryRepository(this._db);

  final AppDatabase _db;

  static const _defaultCategories = [
    ('General', '#0D7C4E'),
    ('Food', '#E65100'),
    ('Beverages', '#1565C0'),
    ('Household', '#6A1B9A'),
  ];

  @override
  Future<void> initialize() async {
    final count = await _db.select(_db.categories).get();
    if (count.isEmpty) {
      for (final (name, color) in _defaultCategories) {
        await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(name: name, color: Value(color)),
            );
      }
    }
  }

  @override
  Stream<List<ProductItem>> watchProducts({String? search}) {
    final query = _db.select(_db.products).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.products.categoryId),
      ),
    ]);

    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      query.where(
        _db.products.name.like(term) | _db.products.barcode.like(term),
      );
    }

    query.orderBy([OrderingTerm.asc(_db.products.name)]);

    return query.watch().map(_mapProductRows);
  }

  @override
  Future<ProductItem?> getProduct(int id) async {
    final query = _db.select(_db.products).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.products.categoryId),
      ),
    ])..where(_db.products.id.equals(id));

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapProductRows(rows).first;
  }

  @override
  Future<ProductItem?> findByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    final query = _db.select(_db.products).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.products.categoryId),
      ),
    ])..where(_db.products.barcode.equals(trimmed));

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapProductRows(rows).first;
  }

  @override
  Future<int> saveProduct({
    int? id,
    required String name,
    String? barcode,
    int? categoryId,
    required double price,
    double cost = 0,
    required int stockQty,
    required int lowStockThreshold,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const InventoryException('Product name is required.');
    }
    if (price < 0) {
      throw const InventoryException('Price cannot be negative.');
    }

    final trimmedBarcode = barcode?.trim();
    final normalizedBarcode =
        trimmedBarcode != null && trimmedBarcode.isNotEmpty ? trimmedBarcode : null;

    if (normalizedBarcode != null) {
      final existing = await (_db.select(_db.products)
            ..where((p) => p.barcode.equals(normalizedBarcode)))
          .getSingleOrNull();
      if (existing != null && existing.id != id) {
        throw InventoryException(
          'Barcode "$normalizedBarcode" is already used by ${existing.name}.',
        );
      }
    }

    final companion = ProductsCompanion(
      name: Value(trimmedName),
      barcode: Value(normalizedBarcode),
      categoryId: Value(categoryId),
      price: Value(price),
      cost: Value(cost),
      stockQty: Value(stockQty),
      lowStockThreshold: Value(lowStockThreshold),
      syncedAt: const Value(null),
    );

    if (id == null) {
      return _db.into(_db.products).insert(companion);
    }

    await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(companion);
    return id;
  }

  @override
  Future<void> deleteProduct(int id) async {
    final inSales = await (_db.select(_db.saleItems)
          ..where((s) => s.productId.equals(id)))
        .get();
    if (inSales.isNotEmpty) {
      throw const InventoryException(
        'Cannot delete — product is linked to past sales.',
      );
    }
    await (_db.delete(_db.products)..where((p) => p.id.equals(id))).go();
  }

  @override
  Stream<List<ProductCategory>> watchCategories() {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch().map(
          (rows) => rows.map(_mapCategory).toList(),
        );
  }

  @override
  Future<int> saveCategory({
    int? id,
    required String name,
    required String color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const InventoryException('Category name is required.');
    }

    final companion = CategoriesCompanion(
      name: Value(trimmedName),
      color: Value(color),
      syncedAt: const Value(null),
    );

    if (id == null) {
      return _db.into(_db.categories).insert(companion);
    }

    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(companion);
    return id;
  }

  @override
  Future<void> deleteCategory(int id) async {
    final products = await (_db.select(_db.products)
          ..where((p) => p.categoryId.equals(id)))
        .get();
    if (products.isNotEmpty) {
      throw const InventoryException(
        'Cannot delete — category still has products.',
      );
    }
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  List<ProductItem> _mapProductRows(List<TypedResult> rows) {
    return rows.map((row) {
      final product = row.readTable(_db.products);
      final category = row.readTableOrNull(_db.categories);
      return ProductItem(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        categoryId: product.categoryId,
        categoryName: category?.name,
        categoryColor: category?.color,
        price: product.price,
        cost: product.cost,
        stockQty: product.stockQty,
        lowStockThreshold: product.lowStockThreshold,
      );
    }).toList();
  }

  ProductCategory _mapCategory(Category row) {
    return ProductCategory(id: row.id, name: row.name, color: row.color);
  }
}
