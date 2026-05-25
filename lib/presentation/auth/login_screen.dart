import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/security/pin_policy.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/data/services/device_role_service.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  bool _obscure = true;
  Future<DeviceRoleMode>? _deviceModeFuture;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > PinPolicy.maxLength) return;
    context.read<AuthCubit>().login(pin);
  }

  @override
  Widget build(BuildContext context) {
    _deviceModeFuture ??= context.read<DeviceRoleService>().getMode();

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      Image.asset(
                        'assets/images/splash_screen.png',
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.store,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sign in',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your PIN to open the store.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<DeviceRoleMode>(
                        future: _deviceModeFuture,
                        builder: (context, snapshot) {
                          final mode =
                              snapshot.data ?? DeviceRoleMode.unrestricted;
                          return Card(
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.phone_android_outlined,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mode.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          mode.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _pinController,
                        obscureText: _obscure,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        child: const Text('Continue'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push(AppRoutes.register),
                        child: const Text('Register new account'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New installs include a bootstrap Admin PIN (1234) for '
                        'recovery. Cashier and Inventory Staff should register '
                        'with a valid pairing code from the admin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading) const LoadingOverlay(message: 'Signing in...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
