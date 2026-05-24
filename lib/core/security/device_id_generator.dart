import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:listapay/core/security/device_id_config.dart';

/// Builds a stable, opaque device ID from a platform identifier and fixed salts.
///
/// Android uses [androidId]; iOS uses [identifierForVendor]. MAC addresses are
/// intentionally not used.
abstract final class DeviceIdGenerator {
  static String generate({
    required String platformLabel,
    required String platformIdentifier,
    required String packageName,
  }) {
    final id = platformIdentifier.trim();
    if (id.isEmpty) {
      throw ArgumentError('platformIdentifier must not be empty');
    }

    final payload = [
      DeviceIdConfig.namespaceSalt,
      DeviceIdConfig.bindingSalt,
      platformLabel,
      id,
      packageName.trim(),
      DeviceIdConfig.vendorSalt,
    ].join('|');

    return sha256.convert(utf8.encode(payload)).toString();
  }
}
