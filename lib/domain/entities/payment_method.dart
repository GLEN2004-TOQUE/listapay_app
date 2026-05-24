enum PaymentMethod {
  cash('cash', 'Cash / On-hand'),
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

  bool get showsEwalletDetails => this == gcash || this == maya;

  String get checkoutSubtitle => switch (this) {
        PaymentMethod.cash => 'Pay with cash on hand',
        PaymentMethod.gcash => 'Customer scans your GCash QR',
        PaymentMethod.maya => 'Customer scans your Maya QR',
        PaymentMethod.utang => 'Record as customer debt',
      };
}
