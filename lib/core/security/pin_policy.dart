/// PIN validation rules for local store auth.
abstract final class PinPolicy {
  static const minLength = 6;
  static const maxLength = 6;

  static const blockedPins = {
    '1234',
    '123456',
    '0000',
    '000000',
    '1111',
    '111111',
    '2222',
    '222222',
    '9999',
    '999999',
    '1212',
    '121212',
  };

  static String? validateNewPin(String pin) {
    final trimmed = pin.trim();
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return 'PIN must be $minLength digits.';
    }
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'PIN must contain digits only.';
    }
    if (blockedPins.contains(trimmed)) {
      return 'Choose a stronger PIN — avoid common patterns.';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(trimmed)) {
      return 'PIN cannot be all the same digit.';
    }
    return null;
  }
}
