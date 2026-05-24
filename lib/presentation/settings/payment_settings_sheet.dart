import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/data/services/payment_config_service.dart';
import 'package:listapay/domain/entities/ewallet_payment_config.dart';
import 'package:listapay/domain/entities/payment_method.dart';

class PaymentSettingsSheet extends StatefulWidget {
  const PaymentSettingsSheet({super.key});

  @override
  State<PaymentSettingsSheet> createState() => _PaymentSettingsSheetState();
}

class _PaymentSettingsSheetState extends State<PaymentSettingsSheet> {
  final _gcashAccountController = TextEditingController();
  final _mayaAccountController = TextEditingController();

  EwalletPaymentConfig? _gcashConfig;
  EwalletPaymentConfig? _mayaConfig;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<PaymentConfigService>();
    final gcash = await service.getConfig(PaymentMethod.gcash);
    final maya = await service.getConfig(PaymentMethod.maya);
    if (!mounted) return;
    setState(() {
      _gcashConfig = gcash;
      _mayaConfig = maya;
      _gcashAccountController.text = gcash.accountNumber ?? '';
      _mayaAccountController.text = maya.accountNumber ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _gcashAccountController.dispose();
    _mayaAccountController.dispose();
    super.dispose();
  }

  Future<void> _saveAccounts() async {
    setState(() => _busy = true);
    final service = context.read<PaymentConfigService>();
    try {
      await service.saveAccountNumber(
        PaymentMethod.gcash,
        _gcashAccountController.text,
      );
      await service.saveAccountNumber(
        PaymentMethod.maya,
        _mayaAccountController.text,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment details saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickQr(PaymentMethod method) async {
    setState(() => _busy = true);
    try {
      await context.read<PaymentConfigService>().pickAndSaveQr(method);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${method.label} QR image updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeQr(PaymentMethod method) async {
    setState(() => _busy = true);
    try {
      await context.read<PaymentConfigService>().removeQr(method);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment methods',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    'Set your GCash and Maya account numbers and QR codes. '
                    'Cashiers will see them at checkout when those methods are selected.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _EwalletSection(
                    method: PaymentMethod.gcash,
                    accountController: _gcashAccountController,
                    config: _gcashConfig!,
                    busy: _busy,
                    onUploadQr: () => _pickQr(PaymentMethod.gcash),
                    onRemoveQr: () => _removeQr(PaymentMethod.gcash),
                  ),
                  const SizedBox(height: 20),
                  _EwalletSection(
                    method: PaymentMethod.maya,
                    accountController: _mayaAccountController,
                    config: _mayaConfig!,
                    busy: _busy,
                    onUploadQr: () => _pickQr(PaymentMethod.maya),
                    onRemoveQr: () => _removeQr(PaymentMethod.maya),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _busy ? null : _saveAccounts,
                    child: const Text('Save account numbers'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}

class _EwalletSection extends StatelessWidget {
  const _EwalletSection({
    required this.method,
    required this.accountController,
    required this.config,
    required this.busy,
    required this.onUploadQr,
    required this.onRemoveQr,
  });

  final PaymentMethod method;
  final TextEditingController accountController;
  final EwalletPaymentConfig config;
  final bool busy;
  final VoidCallback onUploadQr;
  final VoidCallback onRemoveQr;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${method.label} payment',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountController,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '${method.label} account / mobile number',
                hintText: '09XX XXX XXXX',
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'QR code image',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (config.hasQr)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(config.qrImagePath!),
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No QR uploaded',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onUploadQr,
                    icon: const Icon(Icons.upload),
                    label: Text(config.hasQr ? 'Replace QR' : 'Upload QR'),
                  ),
                ),
                if (config.hasQr) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: busy ? null : onRemoveQr,
                    tooltip: 'Remove QR',
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
