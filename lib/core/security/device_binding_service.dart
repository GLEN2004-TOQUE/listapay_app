import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ListaPay/core/security/device_fingerprint_service.dart';

enum DeviceBindingStatus {
  /// First launch on this install — fingerprint stored locally.
  bound,

  /// Fingerprint matches the value stored for this install.
  verified,

  /// Stored fingerprint does not match (cloned data or sideloaded copy).
  duplicateOrCloned,
}

class DeviceBindingResult {
  const DeviceBindingResult({
    required this.status,
    required this.deviceId,
  });

  final DeviceBindingStatus status;
  final String deviceId;

  bool get isAllowed => status != DeviceBindingStatus.duplicateOrCloned;
}

/// Binds ListaPay to a single device fingerprint per app install.
///
/// Prevents reuse of copied app data or a repackaged APK on another phone.
/// Pairing with Supabase should include [DeviceBindingResult.deviceId].
class DeviceBindingService {
  DeviceBindingService({
    DeviceFingerprintService? fingerprint,
    FlutterSecureStorage? storage,
  })  : _fingerprint = fingerprint ?? DeviceFingerprintService(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _boundDeviceIdKey = 'security_bound_device_id';

  final DeviceFingerprintService _fingerprint;
  final FlutterSecureStorage _storage;

  String? _cachedDeviceId;

  Future<String?> getBoundDeviceId() => _storage.read(key: _boundDeviceIdKey);

  Future<String> currentDeviceId() async {
    _cachedDeviceId ??= await _fingerprint.generateDeviceId();
    return _cachedDeviceId!;
  }

  /// Registers or verifies the device fingerprint for this install.
  Future<DeviceBindingResult> verifyOrBind() async {
    if (!_fingerprint.isSupportedPlatform) {
      final id = await _tryGenerateDeviceId();
      return DeviceBindingResult(
        status: DeviceBindingStatus.verified,
        deviceId: id ?? 'unsupported',
      );
    }

    final deviceId = await currentDeviceId();
    final stored = await getBoundDeviceId();

    if (stored == null || stored.isEmpty) {
      await _storage.write(key: _boundDeviceIdKey, value: deviceId);
      debugPrint('ListaPay: device fingerprint bound for this install.');
      return DeviceBindingResult(
        status: DeviceBindingStatus.bound,
        deviceId: deviceId,
      );
    }

    if (stored == deviceId) {
      return DeviceBindingResult(
        status: DeviceBindingStatus.verified,
        deviceId: deviceId,
      );
    }

    debugPrint(
      'ListaPay: device fingerprint mismatch — possible cloned install.',
    );
    return DeviceBindingResult(
      status: DeviceBindingStatus.duplicateOrCloned,
      deviceId: deviceId,
    );
  }

  /// Clears the local binding (e.g. after support-assisted reset).
  Future<void> clearBinding() async {
    _cachedDeviceId = null;
    await _storage.delete(key: _boundDeviceIdKey);
  }

  Future<String?> _tryGenerateDeviceId() async {
    try {
      return await _fingerprint.generateDeviceId();
    } on DeviceFingerprintException {
      return null;
    }
  }
}
