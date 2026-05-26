import 'package:ListaPay/domain/entities/app_user.dart';

class LoginResult {
  const LoginResult({
    required this.user,
    this.mustChangePin = false,
  });

  final AppUser user;
  final bool mustChangePin;
}

abstract class AuthRepository {
  Future<void> initialize();
  Future<AppUser?> getCurrentUser();
  Future<bool> mustChangePinForUser(int userId);
  Future<LoginResult> loginWithPin(String pin);
  Future<AppUser> registerUser({
    required String name,
    required UserRole role,
    required String pin,
  });
  Future<void> changePin({
    required int userId,
    required String currentPin,
    required String newPin,
  });
  Future<void> logout();
}
