enum PaymentMethod {
  cash('cash', 'Cash'),
  gcash('gcash', 'GCash'),
  maya('maya', 'Maya'),
  utang('utang', 'Utang');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethod fromValue(String value) {
    return PaymentMethod.values.firstWhere(
      (m) => m.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }

  bool get requiresCustomer => this == PaymentMethod.utang;
}
