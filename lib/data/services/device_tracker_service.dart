import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:listapay/core/config/device_tracker_config.dart';
import 'package:listapay/core/security/device_binding_service.dart';
import 'package:listapay/core/security/device_fingerprint_service.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/data/services/store_session_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceTrackerResult {
  const DeviceTrackerResult({
    required this.sent,
    this.blocked = false,
    this.isNewDevice = false,
    this.isSuspicious = false,
    this.message,
  });

  final bool sent;
  final bool blocked;
  final bool isNewDevice;
  final bool isSuspicious;
  final String? message;
}

/// Sends device fingerprints to the device tracker API for monitoring.
class DeviceTrackerService {
  DeviceTrackerService({
    DeviceBindingService? deviceBinding,
    DeviceFingerprintService? fingerprint,
    StoreSessionService? storeSession,
    ConnectivityService? connectivity,
    http.Client? httpClient,
    Future<PackageInfo> Function()? packageInfoLoader,
  })  : _deviceBinding = deviceBinding ?? DeviceBindingService(),
        _fingerprint = fingerprint ?? DeviceFingerprintService(),
        _storeSession = storeSession ?? StoreSessionService(),
        _connectivity = connectivity ?? ConnectivityService(),
        _http = httpClient ?? http.Client(),
        _packageInfoLoader =
            packageInfoLoader ?? (() => PackageInfo.fromPlatform());

  final DeviceBindingService _deviceBinding;
  final DeviceFingerprintService _fingerprint;
  final StoreSessionService _storeSession;
  final ConnectivityService _connectivity;
  final http.Client _http;
  final Future<PackageInfo> Function() _packageInfoLoader;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _wasOffline = false;

  Uri get _registerUri =>
      Uri.parse('${DeviceTrackerConfig.apiBaseUrl}/api/register-device');

  /// Registers this device with the tracker API.
  Future<DeviceTrackerResult> registerDevice({String? userId}) async {
    if (!DeviceTrackerConfig.isConfigured) {
      return const DeviceTrackerResult(sent: false);
    }

    if (!await _connectivity.isOnline()) {
      return const DeviceTrackerResult(sent: false, message: 'Offline');
    }

    try {
      final deviceId = await _deviceBinding.currentDeviceId();
      final platform = await _platformLabel();
      final packageInfo = await _packageInfoLoader();
      final session = await _storeSession.getSession();

      final body = <String, dynamic>{
        'device_id': deviceId,
        'platform': platform,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
      };

      if (session != null) {
        body['store_id'] = session.storeId;
        if (session.deviceLabel != null) {
          body['device_label'] = session.deviceLabel;
        }
      }
      if (userId != null && userId.isNotEmpty) {
        body['user_id'] = userId;
      }

      final response = await _http
          .post(
            _registerUri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      final payload = _decodeJson(response.body);
      final blocked = response.statusCode == 403 ||
          payload['blocked'] == true;

      if (blocked) {
        return DeviceTrackerResult(
          sent: true,
          blocked: true,
          message: payload['message']?.toString() ??
              'This device has been blocked by an administrator.',
        );
      }

      if (response.statusCode >= 400) {
        return DeviceTrackerResult(
          sent: false,
          message: payload['message']?.toString() ??
              'Device registration failed (${response.statusCode}).',
        );
      }

      return DeviceTrackerResult(
        sent: true,
        isNewDevice: payload['is_new_device'] == true,
        isSuspicious: payload['is_suspicious'] == true,
      );
    } catch (error, stackTrace) {
      debugPrint('ListaPay device tracker failed: $error');
      debugPrint('$stackTrace');
      return DeviceTrackerResult(
        sent: false,
        message: 'Could not reach device tracker.',
      );
    }
  }

  /// Re-registers when connectivity returns after being offline.
  void startConnectivityListener({Future<void> Function()? onReconnect}) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onlineStream().listen(
      (online) async {
        if (!online) {
          _wasOffline = true;
          return;
        }

        if (!_wasOffline) return;
        _wasOffline = false;

        final result = await registerDevice();
        if (result.sent) {
          await onReconnect?.call();
        }
      },
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _http.close();
  }

  Future<String> _platformLabel() async {
    final kind = await _fingerprint.platformKind();
    return switch (kind) {
      DevicePlatformKind.android => 'Android',
      DevicePlatformKind.ios => 'iOS',
      DevicePlatformKind.unsupported => 'unknown',
    };
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const {};
  }
}
