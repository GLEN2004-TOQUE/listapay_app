enum DebtStatus {
  pending('pending', 'Pending'),
  overdue('overdue', 'Overdue'),
  paid('paid', 'Paid');

  const DebtStatus(this.value, this.label);

  final String value;
  final String label;

  static DebtStatus fromValue(String value) {
    return DebtStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => DebtStatus.pending,
    );
  }

  bool get isActive => this == DebtStatus.pending || this == DebtStatus.overdue;
}
