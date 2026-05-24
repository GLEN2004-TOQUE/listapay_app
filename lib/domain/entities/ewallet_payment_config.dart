import 'dart:io';

/// Store-configured GCash or Maya payment details for checkout display.
class EwalletPaymentConfig {
  const EwalletPaymentConfig({
    this.accountNumber,
    this.qrImagePath,
  });

  final String? accountNumber;
  final String? qrImagePath;

  bool get hasAccount =>
      accountNumber != null && accountNumber!.trim().isNotEmpty;

  bool get hasQr {
    final path = qrImagePath;
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  bool get isConfigured => hasAccount || hasQr;
}
