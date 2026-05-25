import 'package:intl/intl.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/utils/ph_time.dart';

String buildDueSoonSms({
  required String customerName,
  required double amount,
  required DateTime dueDate,
}) {
  final due = PhTime.format(DateFormat('MMM d, yyyy'), dueDate);
  return 'Hi $customerName, mayroon kayong utang na ${formatPeso(amount)} '
      'na dapat bayaran bago ang $due. Salamat! — ListaPay';
}

String buildOverdueSms({
  required String customerName,
  required double remaining,
}) {
  return 'Hi $customerName, overdue na ang utang ninyong ${formatPeso(remaining)}. '
      'Pakibayaran po. Salamat! — ListaPay';
}
