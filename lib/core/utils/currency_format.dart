import 'package:intl/intl.dart';

final _pesoFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

String formatPeso(num amount) => _pesoFormat.format(amount);
