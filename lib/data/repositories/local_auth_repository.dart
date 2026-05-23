import 'package:bcrypt/bcrypt.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/app_user.dart';
import 'package:listapay/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._db);

  final AppDatabase _db;
  static const _sessionUserIdKey = 'session_user_id';

  @override
  Future<void> initialize() async {
    final count = await _db.select(_db.users).get();
    if (count.isEmpty) {
      await _db.into(_db.users).insert(
            UsersCompanion.insert(
              name: 'Admin',
              email: 'admin@listapay.local',
              role: 'admin',
              pinHash: BCrypt.hashpw('1234', BCrypt.gensalt()),
            ),
          );
    }
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
  Future<AppUser> loginWithPin(String pin) async {
    final users = await (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true)))
        .get();

    for (final row in users) {
      if (BCrypt.checkpw(pin, row.pinHash)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_sessionUserIdKey, row.id);
        return _mapUser(row);
      }
    }
    throw const AuthException('Invalid PIN');
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
