import 'dart:io';

import 'package:drift/drift.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ListaPay/data/database/app_database.dart';
import 'package:ListaPay/domain/entities/ewallet_payment_config.dart';
import 'package:ListaPay/domain/entities/payment_method.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists GCash/Maya account numbers and QR images on this device.
class PaymentConfigService {
  PaymentConfigService(this._db);

  final AppDatabase _db;
  final _picker = ImagePicker();

  static String _accountKey(PaymentMethod method) =>
      'payment_${method.value}_account';

  static String _qrPathKey(PaymentMethod method) =>
      'payment_${method.value}_qr_path';

  Future<EwalletPaymentConfig> getConfig(PaymentMethod method) async {
    assert(method.showsEwalletDetails);
    final account = await _readMeta(_accountKey(method));
    final qrPath = await _readMeta(_qrPathKey(method));
    return EwalletPaymentConfig(
      accountNumber: account,
      qrImagePath: qrPath,
    );
  }

  Future<void> saveAccountNumber(
    PaymentMethod method,
    String accountNumber,
  ) async {
    assert(method.showsEwalletDetails);
    await _writeMeta(_accountKey(method), accountNumber.trim());
  }

  Future<String?> pickAndSaveQr(PaymentMethod method) async {
    assert(method.showsEwalletDetails);

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final qrDir = await _ensureQrDirectory();
    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final destPath = p.join(qrDir, '${method.value}_qr$ext');

    await File(picked.path).copy(destPath);
    await _writeMeta(_qrPathKey(method), destPath);
    return destPath;
  }

  Future<void> removeQr(PaymentMethod method) async {
    assert(method.showsEwalletDetails);
    final existing = await _readMeta(_qrPathKey(method));
    if (existing != null && existing.isNotEmpty) {
      final file = File(existing);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _deleteMeta(_qrPathKey(method));
  }

  Future<String> _ensureQrDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'payment_qr'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String?> _readMeta(String key) async {
    final row = await (_db.select(_db.syncMeta)
          ..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    final value = row?.value;
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> _writeMeta(String key, String value) async {
    await _db.into(_db.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            key: key,
            value: Value(value),
          ),
        );
  }

  Future<void> _deleteMeta(String key) async {
    await (_db.delete(_db.syncMeta)..where((m) => m.key.equals(key))).go();
  }
}
