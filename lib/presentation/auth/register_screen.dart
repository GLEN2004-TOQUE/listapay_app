import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ListaPay/core/config/supabase_config.dart';
import 'package:ListaPay/core/router/app_router.dart';
import 'package:ListaPay/core/security/pin_policy.dart';
import 'package:ListaPay/core/theme/app_theme.dart';
import 'package:ListaPay/core/widgets/simple_loading.dart';
import 'package:ListaPay/data/repositories/local_auth_repository.dart';
import 'package:ListaPay/data/services/device_role_service.dart';
import 'package:ListaPay/core/security/device_binding_service.dart';
import 'package:ListaPay/data/services/store_session_service.dart';
import 'package:ListaPay/data/services/sync_service.dart';
import 'package:ListaPay/domain/entities/app_user.dart';
import 'package:ListaPay/domain/repositories/auth_repository.dart';
import 'package:ListaPay/presentation/auth/auth_cubit.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pairingCodeController = TextEditingController();

  UserRole _role = UserRole.admin;
  bool _busy = false;
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  bool get _requiresPairing =>
      _role == UserRole.cashier || _role == UserRole.inventory;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmController.text.trim();
    final pairingCode = _pairingCodeController.text.trim();

    if (name.isEmpty) {
      _showMessage('Name is required.');
      return;
    }
    if (pin != confirmPin) {
      _showMessage('PIN and confirmation do not match.');
      return;
    }
    final pinError = PinPolicy.validateNewPin(pin);
    if (pinError != null) {
      _showMessage(pinError);
      return;
    }
    if (_requiresPairing && pairingCode.isEmpty) {
      _showMessage(
        'A valid pairing code from the admin is required for this role.',
      );
      return;
    }
    if (_requiresPairing && !SupabaseConfig.isConfigured) {
      _showMessage(
        'Cloud pairing is not configured on this build, so staff registration is unavailable.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final bindingService = context.read<DeviceBindingService>();
      final storeSession = context.read<StoreSessionService>();
      final authRepository = context.read<AuthRepository>();
      final deviceRoleService = context.read<DeviceRoleService>();
      final syncService = context.read<SyncService>();
      final authCubit = context.read<AuthCubit>();

      if (_requiresPairing) {
        final deviceId = await bindingService.currentDeviceId();
        await storeSession.pairWithCode(
          pairingCode,
          deviceLabel: _defaultDeviceLabel(_role),
          deviceFingerprint: deviceId,
        );
      }

      await authRepository.registerUser(
        name: name,
        role: _role,
        pin: pin,
      );

      if (_requiresPairing) {
        await deviceRoleService.setMode(_deviceModeFor(_role));
        await syncService.syncNow();
      }

      if (!mounted) return;
      await authCubit.checkSession();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _requiresPairing
                ? 'Account created and device paired successfully.'
                : 'Account created successfully.',
          ),
        ),
      );
      context.go(AppRoutes.home);
    } on StoreSessionException catch (e) {
      _showMessage(e.message);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not complete registration. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Admin',
      UserRole.cashier => 'Cashier',
      UserRole.inventory => 'Inventory Staff',
      UserRole.viewer => 'Viewer',
    };
  }

  String _defaultDeviceLabel(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Admin Device',
      UserRole.cashier => 'Cashier Device',
      UserRole.inventory => 'Inventory Device',
      UserRole.viewer => 'Shared Device',
    };
  }

  DeviceRoleMode _deviceModeFor(UserRole role) {
    return switch (role) {
      UserRole.admin => DeviceRoleMode.admin,
      UserRole.cashier => DeviceRoleMode.cashier,
      UserRole.inventory => DeviceRoleMode.inventory,
      UserRole.viewer => DeviceRoleMode.unrestricted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register account')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Create a role-based account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cashier and Inventory Staff accounts require a valid pairing code from the admin before the account can be created.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Admins can find the current code in Settings -> Cloud sync after the admin device has been paired.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                  DropdownMenuItem(
                    value: UserRole.cashier,
                    child: Text('Cashier'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.inventory,
                    child: Text('Inventory Staff'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _role = value);
                      },
              ),
              if (_requiresPairing) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _pairingCodeController,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Pairing code',
                    helperText:
                        '${_roleLabel(_role)} accounts can only register with a valid admin-issued code.',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                enabled: !_busy,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: PinPolicy.maxLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePin = !_obscurePin),
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                enabled: !_busy,
                obscureText: _obscureConfirm,
                keyboardType: TextInputType.number,
                maxLength: PinPolicy.maxLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Register'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: const Text('Back to sign in'),
              ),
              const SizedBox(height: 8),
              Text(
                'New installs still include a bootstrap Admin PIN (1234) for recovery. Change it after first sign-in.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (_busy) const LoadingOverlay(message: 'Creating account...'),
        ],
      ),
    );
  }
}
