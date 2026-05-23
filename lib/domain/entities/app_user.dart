import 'package:equatable/equatable.dart';

enum UserRole { admin, cashier, viewer }

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;

  bool get isAdmin => role == UserRole.admin;
  bool get canSell => role == UserRole.admin || role == UserRole.cashier;

  @override
  List<Object?> get props => [id, name, email, role, isActive];
}
