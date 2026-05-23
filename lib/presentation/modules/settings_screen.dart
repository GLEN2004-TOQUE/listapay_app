import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/data/services/debt_sms_reminder_service.dart';
import 'package:listapay/data/services/notification_service.dart';
import 'package:listapay/data/services/sms_service.dart';
import 'package:listapay/presentation/modules/module_scaffold.dart';
import 'package:listapay/presentation/settings/sms_settings_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.read<ConnectivityService>();
    final notifications = context.read<NotificationService>();
    final sms = context.read<SmsService>();

    return ModuleScaffold(
      title: 'Settings',
      icon: Icons.settings_outlined,
      emptyTitle: '',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<bool>(
            stream: connectivity.onlineStream(),
            initialData: true,
            builder: (context, snapshot) {
              final online = snapshot.data ?? true;
              return Card(
                child: ListTile(
                  leading: Icon(
                    online ? Icons.cloud_done : Icons.cloud_off,
                    color: online ? AppColors.primary : AppColors.offline,
                  ),
                  title: Text(online ? 'Online' : 'Offline'),
                  subtitle: Text(
                    online
                        ? 'SMS reminders available when configured'
                        : 'SMS queued until back online',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Semaphore SMS'),
                  subtitle: FutureBuilder<bool>(
                    future: sms.hasApiKey(),
                    builder: (context, snapshot) {
                      final configured = snapshot.data ?? false;
                      return Text(
                        configured
                            ? 'API key configured'
                            : 'Set API key for debt SMS',
                      );
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const SmsSettingsSheet(),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync now'),
                  subtitle: const Text('Coming in Phase 7'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync engine not connected yet.'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Test notification'),
                  onTap: () async {
                    await notifications.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification sent.')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Check debts now'),
                  subtitle: const Text('Local alerts + SMS if online'),
                  onTap: () async {
                    await notifications.runDebtChecks();
                    final result =
                        await context.read<DebtSmsReminderService>().processReminders();
                    await context.read<DebtSmsReminderService>().processRetryQueue();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Done. SMS sent: ${result.sent}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMS reminders (Phase 6)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const _AlertRow(
                    icon: Icons.schedule,
                    title: 'Due within 3 days',
                    subtitle: 'Tagalog SMS to customer when online',
                  ),
                  const _AlertRow(
                    icon: Icons.warning_amber_outlined,
                    title: 'Overdue',
                    subtitle: 'SMS for past-due debts when online',
                  ),
                  const _AlertRow(
                    icon: Icons.replay,
                    title: 'Retry queue',
                    subtitle: 'Failed SMS retry up to 5 times',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
