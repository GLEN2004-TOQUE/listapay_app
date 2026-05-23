import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/domain/entities/product_item.dart';

void main() {
  test('formatPeso formats Philippine peso', () {
    expect(formatPeso(100), contains('100'));
    expect(formatPeso(100), contains('₱'));
  });

  test('ProductItem isLowStock when at threshold', () {
    const product = ProductItem(
      id: 1,
      name: 'Test',
      price: 10,
      cost: 5,
      stockQty: 5,
      lowStockThreshold: 5,
    );
    expect(product.isLowStock, isTrue);
  });
}
