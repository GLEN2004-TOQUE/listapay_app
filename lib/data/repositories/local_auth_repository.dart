import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:listapay/core/security/pin_lockout_service.dart';
import 'package:listapay/core/security/pin_policy.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/app_user.dart';
import 'package:listapay/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(
    this._db, {
    PinLockoutService? lockout,
  }) : _lockout = lockout ?? PinLockoutService();

  final AppDatabase _db;
  final PinLockoutService _lockout;

  static const _sessionUserIdKey = 'session_user_id';
  static String _mustChangePinKey(int userId) => 'must_change_pin_$userId';

  @override
  Future<void> initialize() async {
    final count = await _db.select(_db.users).get();
    if (count.isEmpty) {
      final id = await _db.into(_db.users).insert(
            UsersCompanion.insert(
              name: 'Admin',
              email: 'admin@listapay.local',
              role: 'admin',
              pinHash: BCrypt.hashpw('1234', BCrypt.gensalt()),
            ),
          );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mustChangePinKey(id), true);
    } else {
      await _flagDefaultPinIfNeeded();
    }
  }

  Future<void> _flagDefaultPinIfNeeded() async {
    final admins = await (_db.select(_db.users)
          ..where((u) => u.role.equals('admin') & u.isActive.equals(true)))
        .get();

    final prefs = await SharedPreferences.getInstance();
    for (final admin in admins) {
      if (prefs.getBool(_mustChangePinKey(admin.id)) ?? false) continue;
      if (BCrypt.checkpw('1234', admin.pinHash)) {
        await prefs.setBool(_mustChangePinKey(admin.id), true);
      }
    }
  }

  @override
  Future<bool> mustChangePinForUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mustChangePinKey(userId)) ?? false;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_sessionUserIdKey);
    if (userId == null) return null;

    final row = await (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (row == null || !row.isActive) return null;
    return _mapUser(row);
  }

  @override
  Future<LoginResult> loginWithPin(String pin) async {
    final lockout = await _lockout.remainingLockout();
    if (lockout != null) {
      final minutes = lockout.inMinutes.clamp(1, 999);
      throw AuthException(
        'Too many attempts. Try again in $minutes minute${minutes == 1 ? '' : 's'}.',
      );
    }

    final users = await (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true)))
        .get();

    for (final row in users) {
      if (BCrypt.checkpw(pin, row.pinHash)) {
        await _lockout.recordSuccess();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_sessionUserIdKey, row.id);
        final mustChange = await mustChangePinForUser(row.id);
        return LoginResult(user: _mapUser(row), mustChangePin: mustChange);
      }
    }

    await _lockout.recordFailure();
    final lockoutAfter = await _lockout.remainingLockout();
    if (lockoutAfter != null) {
      final minutes = lockoutAfter.inMinutes.clamp(1, 999);
      throw AuthException(
        'Too many attempts. Try again in $minutes minute${minutes == 1 ? '' : 's'}.',
      );
    }
    throw const AuthException('Invalid PIN');
  }

  @override
  Future<void> changePin({
    required int userId,
    required String currentPin,
    required String newPin,
  }) async {
    final validationError = PinPolicy.validateNewPin(newPin);
    if (validationError != null) {
      throw AuthException(validationError);
    }

    final row = await (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (row == null || !row.isActive) {
      throw const AuthException('User not found.');
    }
    if (!BCrypt.checkpw(currentPin, row.pinHash)) {
      throw const AuthException('Current PIN is incorrect.');
    }
    if (BCrypt.checkpw(newPin, row.pinHash)) {
      throw const AuthException('New PIN must be different from the current PIN.');
    }

    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(pinHash: Value(BCrypt.hashpw(newPin, BCrypt.gensalt()))),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mustChangePinKey(userId));
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
  }

  AppUser _mapUser(User row) {
    return AppUser(
      id: row.id,
      name: row.name,
      email: row.email,
      role: _parseRole(row.role),
      isActive: row.isActive,
    );
  }

  UserRole _parseRole(String role) {
    return switch (role) {
      'admin' => UserRole.admin,
      'cashier' => UserRole.cashier,
      'viewer' => UserRole.viewer,
      _ => UserRole.cashier,
    };
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
