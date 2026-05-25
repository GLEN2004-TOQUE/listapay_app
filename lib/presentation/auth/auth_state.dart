part of 'auth_cubit.dart';

enum AuthStatus { unknown, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.requiresPinChange = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AppUser user, {bool requiresPinChange = false})
    : this(
        status: AuthStatus.authenticated,
        user: user,
        requiresPinChange: requiresPinChange,
      );

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;
  final bool requiresPinChange;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
    bool? requiresPinChange,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      requiresPinChange: requiresPinChange ?? this.requiresPinChange,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, requiresPinChange];
}
