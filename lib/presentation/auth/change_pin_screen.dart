import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ListaPay/core/router/app_router.dart';
import 'package:ListaPay/core/security/pin_policy.dart';
import 'package:ListaPay/core/theme/app_theme.dart';
import 'package:ListaPay/core/widgets/simple_loading.dart';
import 'package:ListaPay/presentation/auth/auth_cubit.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({
    super.key,
    this.forced = false,
  });

  /// When true, user must set a new PIN before using the app (no back).
  final bool forced;

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final newPin = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (newPin != confirm) {
      _showError('New PIN and confirmation do not match.');
      return;
    }

    final policyError = PinPolicy.validateNewPin(newPin);
    if (policyError != null) {
      _showError(policyError);
      return;
    }

    setState(() => _busy = true);
    final error = await context.read<AuthCubit>().changePin(
          currentPin: current,
          newPin: newPin,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _showError(error);
      return;
    }

    if (widget.forced) {
      context.go(AppRoutes.home);
    } else {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated successfully.')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forced = widget.forced;

    return PopScope(
      canPop: !forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !forced,
          title: Text(forced ? 'Set your PIN' : 'Change PIN'),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (forced) ...[
                    Icon(
                      Icons.lock_reset,
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create a secure PIN',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The default PIN must be changed before you can use ListaPay. '
                      'Use ${PinPolicy.minLength} digits that only you know.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _pinField(
                    controller: _currentController,
                    label: 'Current PIN',
                    obscure: _obscureCurrent,
                    onToggle: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  const SizedBox(height: 16),
                  _pinField(
                    controller: _newController,
                    label: 'New PIN',
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  const SizedBox(height: 16),
                  _pinField(
                    controller: _confirmController,
                    label: 'Confirm new PIN',
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(forced ? 'Save and continue' : 'Update PIN'),
                  ),
                ],
              ),
            ),
            if (_busy) const LoadingOverlay(message: 'Updating PIN...'),
          ],
        ),
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: PinPolicy.maxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
