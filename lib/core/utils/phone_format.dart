/// Normalizes Philippine mobile numbers to Semaphore format (639XXXXXXXXX).
String? normalizePhilippinePhone(String? input) {
  if (input == null) return null;

  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (digits.startsWith('63')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.length != 10 || !digits.startsWith('9')) {
    return null;
  }

  return '63$digits';
}
