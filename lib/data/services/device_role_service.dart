import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ListaPay/domain/entities/app_user.dart';

enum DeviceRoleMode { unrestricted, admin, cashier, inventory }

extension DeviceRoleModeX on DeviceRoleMode {
  String get storageValue => switch (this) {
    DeviceRoleMode.unrestricted => 'unrestricted',
    DeviceRoleMode.admin => 'admin',
    DeviceRoleMode.cashier => 'cashier',
    DeviceRoleMode.inventory => 'inventory',
  };

  String get label => switch (this) {
    DeviceRoleMode.unrestricted => 'Shared device',
    DeviceRoleMode.admin => 'Admin device',
    DeviceRoleMode.cashier => 'Cashier device',
    DeviceRoleMode.inventory => 'Inventory device',
  };

  String get description => switch (this) {
    DeviceRoleMode.unrestricted =>
      'Admin, cashier, and inventory accounts can sign in here.',
    DeviceRoleMode.admin =>
      'Only admin accounts can sign in on this device.',
    DeviceRoleMode.cashier =>
      'Cashier accounts sign in here. Admins can still sign in to manage it.',
    DeviceRoleMode.inventory =>
      'Inventory accounts sign in here. Admins can still sign in to manage it.',
  };
}

class DeviceRoleService {
  DeviceRoleService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceRoleModeKey = 'device_role_mode';

  final FlutterSecureStorage _storage;

  Future<DeviceRoleMode> getMode() async {
    final value = await _storage.read(key: _deviceRoleModeKey);
    return switch (value) {
      'admin' => DeviceRoleMode.admin,
      'cashier' => DeviceRoleMode.cashier,
      'inventory' => DeviceRoleMode.inventory,
      _ => DeviceRoleMode.unrestricted,
    };
  }

  Future<void> setMode(DeviceRoleMode mode) async {
    if (mode == DeviceRoleMode.unrestricted) {
      await _storage.delete(key: _deviceRoleModeKey);
      return;
    }
    await _storage.write(key: _deviceRoleModeKey, value: mode.storageValue);
  }

  bool canUseDevice(AppUser user, DeviceRoleMode mode) {
    if (mode == DeviceRoleMode.unrestricted || user.isAdmin) return true;
    return switch (mode) {
      DeviceRoleMode.unrestricted => true,
      DeviceRoleMode.admin => user.role == UserRole.admin,
      DeviceRoleMode.cashier => user.role == UserRole.cashier,
      DeviceRoleMode.inventory => user.role == UserRole.inventory,
    };
  }

  Future<bool> canUserUseOnThisDevice(AppUser user) async {
    final mode = await getMode();
    return canUseDevice(user, mode);
  }

  String blockedMessage(DeviceRoleMode mode) {
    return switch (mode) {
      DeviceRoleMode.unrestricted =>
        'This device is available for all store roles.',
      DeviceRoleMode.admin =>
        'This device is locked to Admin mode. Sign in with an admin PIN or ask an admin to change the device mode.',
      DeviceRoleMode.cashier =>
        'This device is locked to Cashier mode. Sign in with a cashier PIN or ask an admin to change the device mode.',
      DeviceRoleMode.inventory =>
        'This device is locked to Inventory mode. Sign in with an inventory PIN or ask an admin to change the device mode.',
    };
  }
}
