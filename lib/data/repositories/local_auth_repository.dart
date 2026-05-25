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
  static const _bootstrapUsers = [
    (
      name: 'Admin',
      email: 'admin@listapay.local',
      role: 'admin',
      defaultPin: '1234',
    ),
  ];

  @override
  Future<void> initialize() async {
    await _ensureBootstrapUsers();
    await _flagDefaultPinsIfNeeded();
  }

  Future<void> _ensureBootstrapUsers() async {
    final prefs = await SharedPreferences.getInstance();
    for (final seed in _bootstrapUsers) {
      final existing =
          await (_db.select(_db.users)
                ..where((u) => u.email.equals(seed.email)))
              .getSingleOrNull();
      if (existing != null) continue;

      final id = await _db.into(_db.users).insert(
            UsersCompanion.insert(
              name: seed.name,
              email: seed.email,
              role: seed.role,
              pinHash: BCrypt.hashpw(seed.defaultPin, BCrypt.gensalt()),
            ),
          );
      await prefs.setBool(_mustChangePinKey(id), true);
    }
  }

  Future<void> _flagDefaultPinsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    for (final seed in _bootstrapUsers) {
      final user =
          await (_db.select(_db.users)
                ..where((u) => u.email.equals(seed.email) & u.isActive.equals(true)))
              .getSingleOrNull();
      if (user == null) continue;
      if (prefs.getBool(_mustChangePinKey(user.id)) ?? false) continue;
      if (BCrypt.checkpw(seed.defaultPin, user.pinHash)) {
        await prefs.setBool(_mustChangePinKey(user.id), true);
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
  Future<AppUser> registerUser({
    required String name,
    required UserRole role,
    required String pin,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const AuthException('Name is required.');
    }

    final validationError = PinPolicy.validateNewPin(pin);
    if (validationError != null) {
      throw AuthException(validationError);
    }

    final existingPinUser = await _findUserByPin(pin);
    if (existingPinUser != null) {
      throw const AuthException(
        'That PIN is already in use by another account. Choose a different PIN.',
      );
    }

    final internalEmail =
        '${role.name}.${DateTime.now().microsecondsSinceEpoch}@listapay.local';
    final id = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            name: trimmedName,
            email: internalEmail,
            role: role.name,
            pinHash: BCrypt.hashpw(pin, BCrypt.gensalt()),
          ),
        );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mustChangePinKey(id));
    await prefs.setInt(_sessionUserIdKey, id);

    final row = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingle();
    return _mapUser(row);
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
    final duplicatePinUser = await _findUserByPin(newPin, exceptUserId: userId);
    if (duplicatePinUser != null) {
      throw const AuthException(
        'That PIN is already in use by another account. Choose a different PIN.',
      );
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
      'inventory' => UserRole.inventory,
      'viewer' => UserRole.viewer,
      _ => UserRole.viewer,
    };
  }

  Future<User?> _findUserByPin(String pin, {int? exceptUserId}) async {
    final users = await (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true)))
        .get();
    for (final user in users) {
      if (exceptUserId != null && user.id == exceptUserId) continue;
      if (BCrypt.checkpw(pin, user.pinHash)) {
        return user;
      }
    }
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
