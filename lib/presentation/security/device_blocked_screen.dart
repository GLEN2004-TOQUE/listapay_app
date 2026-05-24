import 'package:flutter/material.dart';
import 'package:listapay/core/theme/app_theme.dart';

/// Shown when this install's fingerprint does not match the bound device.
class DeviceBlockedScreen extends StatelessWidget {
  const DeviceBlockedScreen({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final body = message ??
        'This copy of ListaPay is not authorized on this device. '
        'Copied app data or a duplicate install was detected. '
        'Use the official app from your store administrator.';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.phonelink_erase_outlined,
                size: 72,
                color: AppColors.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Device not authorized',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
