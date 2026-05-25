import 'package:flutter/material.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/widgets/simple_loading.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _splashLogoAsset = 'assets/images/LISTAPAY-LOGO.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _splashLogoAsset,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.store_rounded,
                    size: 96,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const BrandedLoadingIndicator(size: 88),
                const SizedBox(height: 24),
                Text(
                  'Preparing your store...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
