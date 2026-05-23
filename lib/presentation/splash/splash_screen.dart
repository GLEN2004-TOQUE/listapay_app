import 'package:flutter/material.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/widgets/simple_loading.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Image.asset(
              'assets/images/LISTAPAY-LOGO.png',
              height: 120,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.store,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ListaPay',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Offline-first POS',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const Spacer(),
            const SimpleLoading(message: 'Loading store...'),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
