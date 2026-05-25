import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/domain/entities/ewallet_payment_config.dart';
import 'package:listapay/domain/entities/payment_method.dart';

/// Shows GCash/Maya account number and QR for the customer to scan at checkout.
class PaymentQrPanel extends StatelessWidget {
  const PaymentQrPanel({super.key, required this.method, required this.config});

  final PaymentMethod method;
  final EwalletPaymentConfig config;

  @override
  Widget build(BuildContext context) {
    if (!method.showsEwalletDetails) return const SizedBox.shrink();

    final account = config.accountNumber?.trim();
    final hasAccount = account != null && account.isNotEmpty;
    final hasQr = config.hasQr;

    if (!hasAccount && !hasQr) {
      return Card(
        color: AppColors.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No ${method.label} account or QR set up yet. '
                  'Ask your admin to add them in Settings → Payment methods.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pay via ${method.label}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Show this to the customer before confirming the sale.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (hasAccount) ...[
              const SizedBox(height: 16),
              Text(
                'Account number',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      account,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy account number',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: account));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account number copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
            ],
            if (hasQr) ...[
              const SizedBox(height: 16),
              Text(
                'Scan to pay',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: Image.file(
                      File(config.qrImagePath!),
                      height: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('QR image could not be loaded.'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
