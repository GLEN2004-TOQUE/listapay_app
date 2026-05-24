/// Fixed strings mixed with platform identifiers when deriving the device ID.
///
/// Changing these values invalidates previously bound devices.
abstract final class DeviceIdConfig {
  static const namespaceSalt = 'LISTAPAY_DEVICE_NAMESPACE_V1';
  static const bindingSalt = 'LISTAPAY_ANTI_PIRACY_BINDING';
  static const vendorSalt = 'DEBTPAY_LISTAPAY_STORE_POS';
  static const androidPlatformLabel = 'android';
  static const iosPlatformLabel = 'ios';
}
