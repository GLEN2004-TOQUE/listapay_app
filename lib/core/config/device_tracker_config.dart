/// Device tracker API settings.
///
/// Pass your API URL at build/run time:
/// `flutter run --dart-define=DEVICE_TRACKER_URL=http://192.168.1.10:3000`
abstract final class DeviceTrackerConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'DEVICE_TRACKER_URL',
    defaultValue: '',
  );

  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
