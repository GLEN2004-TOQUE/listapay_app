import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/data/repositories/local_auth_repository.dart';
import 'package:listapay/domain/entities/app_user.dart';
import 'package:listapay/domain/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepository) : super(const AuthState.unknown());

  final AuthRepository _authRepository;

  Future<void> checkSession() async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        final mustChange = await _authRepository.mustChangePinForUser(user.id);
        emit(AuthState.authenticated(user, requiresPinChange: mustChange));
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (_) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> login(String pin) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final result = await _authRepository.loginWithPin(pin);
      emit(
        AuthState.authenticated(
          result.user,
          requiresPinChange: result.mustChangePin,
        ),
      );
    } on AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Login failed. Try again.',
      ));
    }
  }

  Future<String?> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final user = state.user;
    if (user == null) return 'Not signed in.';

    try {
      await _authRepository.changePin(
        userId: user.id,
        currentPin: currentPin,
        newPin: newPin,
      );
      emit(AuthState.authenticated(user));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update PIN. Try again.';
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emit(const AuthState.unauthenticated());
  }
}
