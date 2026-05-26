import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ListaPay/core/theme/app_theme.dart';
import 'package:ListaPay/core/widgets/simple_loading.dart';
import 'package:ListaPay/data/services/device_role_service.dart';

class DeviceModeSheet extends StatefulWidget {
  const DeviceModeSheet({super.key});

  @override
  State<DeviceModeSheet> createState() => _DeviceModeSheetState();
}

class _DeviceModeSheetState extends State<DeviceModeSheet> {
  DeviceRoleMode? _selectedMode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await context.read<DeviceRoleService>().getMode();
    if (mounted) {
      setState(() => _selectedMode = mode);
    }
  }

  Future<void> _save() async {
    final mode = _selectedMode;
    if (mode == null) return;

    setState(() => _busy = true);
    await context.read<DeviceRoleService>().setMode(mode);
    if (!mounted) return;
    Navigator.pop(context, mode);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode = _selectedMode;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        child: selectedMode == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: BrandedLoadingIndicator(size: 36),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Device mode',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose what this phone is mainly used for. Admins can still '
                    'sign in on any device to manage it.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioGroup<DeviceRoleMode>(
                    groupValue: selectedMode,
                    onChanged: (value) {
                      if (_busy || value == null) return;
                      setState(() => _selectedMode = value);
                    },
                    child: Column(
                      children: DeviceRoleMode.values
                          .map(
                            (mode) => RadioListTile<DeviceRoleMode>(
                              value: mode,
                              title: Text(mode.label),
                              subtitle: Text(mode.description),
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const BrandedLoadingIndicator(
                            size: 20,
                            strokeWidth: 2,
                            showHalo: false,
                          )
                        : const Text('Save device mode'),
                  ),
                ],
              ),
      ),
    );
  }
}
