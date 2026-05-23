import 'package:listapay/domain/entities/app_user.dart';

abstract class AuthRepository {
  Future<void> initialize();
  Future<AppUser?> getCurrentUser();
  Future<AppUser> loginWithPin(String pin);
  Future<void> logout();
}
