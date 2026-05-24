import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:listapay/core/security/device_id_config.dart';
import 'package:listapay/core/security/device_id_generator.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum DevicePlatformKind { android, ios, unsupported }

/// Reads Android ID / iOS IdentifierForVendor and derives the ListaPay device ID.
class DeviceFingerprintService {
  DeviceFingerprintService({
    DeviceInfoPlugin? deviceInfo,
    Future<PackageInfo> Function()? packageInfoLoader,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _packageInfoLoader =
            packageInfoLoader ?? (() => PackageInfo.fromPlatform());

  final DeviceInfoPlugin _deviceInfo;
  final Future<PackageInfo> Function() _packageInfoLoader;

  /// Whether this platform participates in device binding.
  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<DevicePlatformKind> platformKind() async {
    if (kIsWeb) return DevicePlatformKind.unsupported;
    if (Platform.isAndroid) return DevicePlatformKind.android;
    if (Platform.isIOS) return DevicePlatformKind.ios;
    return DevicePlatformKind.unsupported;
  }

  /// Raw platform identifier before hashing (Android ID or IdentifierForVendor).
  Future<String> readPlatformIdentifier() async {
    final kind = await platformKind();
    switch (kind) {
      case DevicePlatformKind.android:
        final info = await _deviceInfo.androidInfo;
        final androidId = info.id.trim();
        if (androidId.isEmpty) {
          throw const DeviceFingerprintException(
            'Could not read Android ID on this device.',
          );
        }
        return androidId;
      case DevicePlatformKind.ios:
        final info = await _deviceInfo.iosInfo;
        final vendorId = info.identifierForVendor?.trim();
        if (vendorId == null || vendorId.isEmpty) {
          throw const DeviceFingerprintException(
            'Could not read IdentifierForVendor on this device.',
          );
        }
        return vendorId;
      case DevicePlatformKind.unsupported:
        throw const DeviceFingerprintException(
          'Device binding is only available on Android and iOS.',
        );
    }
  }

  /// SHA-256 device fingerprint sent to the server and used for local binding.
  Future<String> generateDeviceId() async {
    final kind = await platformKind();
    final platformIdentifier = await readPlatformIdentifier();
    final packageInfo = await _packageInfoLoader();

    final platformLabel = switch (kind) {
      DevicePlatformKind.android => DeviceIdConfig.androidPlatformLabel,
      DevicePlatformKind.ios => DeviceIdConfig.iosPlatformLabel,
      DevicePlatformKind.unsupported => 'unsupported',
    };

    return DeviceIdGenerator.generate(
      platformLabel: platformLabel,
      platformIdentifier: platformIdentifier,
      packageName: packageInfo.packageName,
    );
  }
}

class DeviceFingerprintException implements Exception {
  const DeviceFingerprintException(this.message);
  final String message;

  @override
  String toString() => message;
}
