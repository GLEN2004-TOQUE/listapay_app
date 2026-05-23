import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/domain/entities/cart_line.dart';
import 'package:listapay/domain/entities/payment_method.dart';

void main() {
  test('CartLine subtotal is price times qty', () {
    const line = CartLine(
      productId: 1,
      name: 'Rice',
      unitPrice: 50,
      qty: 3,
      maxStock: 10,
    );
    expect(line.subtotal, 150);
  });

  test('Utang payment requires customer', () {
    expect(PaymentMethod.utang.requiresCustomer, isTrue);
    expect(PaymentMethod.cash.requiresCustomer, isFalse);
  });
}
