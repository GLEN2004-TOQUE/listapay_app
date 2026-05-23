import 'package:flutter/material.dart';
import 'package:listapay/core/theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.offline.withValues(alpha: 0.12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppColors.offline),
          SizedBox(width: 6),
          Text(
            'Offline mode — data saved locally',
            style: TextStyle(fontSize: 12, color: AppColors.offline),
          ),
        ],
      ),
    );
  }
}
