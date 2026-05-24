import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:listapay/core/security/device_binding_service.dart';
import 'package:listapay/core/security/device_fingerprint_service.dart';
import 'package:listapay/core/security/device_id_config.dart';
import 'package:listapay/core/security/device_id_generator.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final mockVault = <String, String>{};

  setUp(() {
    mockVault.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return mockVault[key];
        case 'write':
          mockVault[key] = args['value'] as String;
          return null;
        case 'delete':
          mockVault.remove(key);
          return null;
        case 'deleteAll':
          mockVault.clear();
          return null;
        case 'containsKey':
          return mockVault.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('DeviceIdGenerator', () {
    test('produces stable SHA-256 for same inputs', () {
      final first = DeviceIdGenerator.generate(
        platformLabel: DeviceIdConfig.androidPlatformLabel,
        platformIdentifier: '9774d56d682e549c',
        packageName: 'com.example.listapay',
      );
      final second = DeviceIdGenerator.generate(
        platformLabel: DeviceIdConfig.androidPlatformLabel,
        platformIdentifier: '9774d56d682e549c',
        packageName: 'com.example.listapay',
      );

      expect(first, second);
      expect(first.length, 64);
    });

    test('differs when platform identifier changes', () {
      final android = DeviceIdGenerator.generate(
        platformLabel: DeviceIdConfig.androidPlatformLabel,
        platformIdentifier: 'android-id-a',
        packageName: 'com.example.listapay',
      );
      final ios = DeviceIdGenerator.generate(
        platformLabel: DeviceIdConfig.iosPlatformLabel,
        platformIdentifier: 'ios-vendor-a',
        packageName: 'com.example.listapay',
      );

      expect(android, isNot(ios));
    });

    test('rejects empty platform identifier', () {
      expect(
        () => DeviceIdGenerator.generate(
          platformLabel: DeviceIdConfig.androidPlatformLabel,
          platformIdentifier: '',
          packageName: 'com.example.listapay',
        ),
        throwsArgumentError,
      );
    });
  });

  group('DeviceBindingService', () {
    test('binds on first verify and accepts matching fingerprint', () async {
      final fingerprint = DeviceFingerprintService(
        packageInfoLoader: () async => PackageInfo(
          appName: 'ListaPay',
          packageName: 'com.example.listapay',
          version: '1.0.0',
          buildNumber: '1',
        ),
      );

      var calls = 0;
      final binding = DeviceBindingService(
        storage: const FlutterSecureStorage(),
        fingerprint: _FakeFingerprintService(
          deviceId: 'test-device-hash',
          onGenerate: () => calls++,
        ),
      );

      final first = await binding.verifyOrBind();
      expect(first.status, DeviceBindingStatus.bound);
      expect(first.deviceId, 'test-device-hash');
      expect(calls, 1);

      final second = await binding.verifyOrBind();
      expect(second.status, DeviceBindingStatus.verified);
      expect(calls, 1);
    });

    test('blocks when stored fingerprint differs', () async {
      const storage = FlutterSecureStorage();
      final binding = DeviceBindingService(
        storage: storage,
        fingerprint: _FakeFingerprintService(deviceId: 'bound-hash'),
      );

      await binding.verifyOrBind();

      final tampered = DeviceBindingService(
        storage: storage,
        fingerprint: _FakeFingerprintService(deviceId: 'other-hash'),
      );
      final blocked = await tampered.verifyOrBind();

      expect(blocked.status, DeviceBindingStatus.duplicateOrCloned);
      expect(blocked.isAllowed, isFalse);
    });
  });
}

class _FakeFingerprintService extends DeviceFingerprintService {
  _FakeFingerprintService({
    required this.deviceId,
    this.onGenerate,
  }) : super(
          packageInfoLoader: () async => PackageInfo(
                appName: 'ListaPay',
                packageName: 'com.example.listapay',
                version: '1.0.0',
                buildNumber: '1',
              ),
        );

  final String deviceId;
  final void Function()? onGenerate;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<String> generateDeviceId() async {
    onGenerate?.call();
    return deviceId;
  }
}
