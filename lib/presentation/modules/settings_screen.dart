import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ListaPay/core/config/supabase_config.dart';
import 'package:ListaPay/core/router/app_router.dart';
import 'package:ListaPay/core/theme/app_theme.dart';
import 'package:ListaPay/data/services/connectivity_service.dart';
import 'package:ListaPay/data/services/debt_sms_reminder_service.dart';
import 'package:ListaPay/data/services/device_role_service.dart';
import 'package:ListaPay/data/services/notification_service.dart';
import 'package:ListaPay/data/services/sms_service.dart';
import 'package:ListaPay/data/services/store_session_service.dart';
import 'package:ListaPay/data/services/sync_service.dart';
import 'package:ListaPay/presentation/auth/auth_cubit.dart';
import 'package:ListaPay/presentation/modules/module_scaffold.dart';
import 'package:ListaPay/presentation/settings/device_mode_sheet.dart';
import 'package:ListaPay/presentation/settings/payment_settings_sheet.dart';
import 'package:ListaPay/presentation/settings/sms_settings_sheet.dart';
import 'package:ListaPay/presentation/settings/sync_settings_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user!;
    final isAdmin = user.isAdmin;
    final connectivity = context.read<ConnectivityService>();
    final notifications = context.read<NotificationService>();
    final sms = context.read<SmsService>();
    final deviceRole = context.read<DeviceRoleService>();
    final storeSession = context.read<StoreSessionService>();
    final sync = context.read<SyncService>();

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
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Change PIN'),
                  subtitle: const Text('Update your sign-in PIN on this device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.changePin, extra: true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: const Text('Device mode'),
                  subtitle: FutureBuilder<DeviceRoleMode>(
                    future: deviceRole.getMode(),
                    builder: (context, snapshot) {
                      final mode = snapshot.data ?? DeviceRoleMode.unrestricted;
                      return Text(
                        isAdmin
                            ? mode.description
                            : '${mode.label}. Only admins can change this.',
                      );
                    },
                  ),
                  trailing: Icon(
                    isAdmin ? Icons.chevron_right : Icons.lock_outline,
                  ),
                  onTap: () async {
                    if (!isAdmin) {
                      final mode = await deviceRole.getMode();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${mode.label} is active on this phone. Ask an admin to change it.',
                          ),
                        ),
                      );
                      return;
                    }

                    final selected = await showModalBottomSheet<DeviceRoleMode>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const DeviceModeSheet(),
                    );
                    if (!context.mounted || selected == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Device mode updated to ${selected.label.toLowerCase()}.',
                        ),
                      ),
                    );
                  },
                ),
                if (isAdmin) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Cloud sync'),
                    subtitle: FutureBuilder<StoreSession?>(
                      future: storeSession.getSession(),
                      builder: (context, snapshot) {
                        final session = snapshot.data;
                        final subtitle = !SupabaseConfig.isConfigured
                            ? 'Cloud sync disabled on this build'
                            : session != null
                            ? 'Paired with ${session.storeName}'
                            : 'Not paired yet — tap to connect';
                        return Text(
                          subtitle,
                        );
                      },
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const SyncSettingsSheet(),
                      );
                    },
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync now'),
                  subtitle: const Text('Push local changes and pull updates'),
                  onTap: () async {
                    final result = await sync.syncNow();
                    if (!context.mounted) return;
                    final text = result.skipped
                        ? (result.message ?? 'Sync skipped')
                        : result.message ??
                            'Synced — pushed ${result.pushed}, pulled ${result.pulled}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(text)),
                    );
                  },
                ),
                if (isAdmin) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.qr_code_2),
                    title: const Text('Payment methods'),
                    subtitle: const Text(
                      'GCash & Maya QR codes and account numbers',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const PaymentSettingsSheet(),
                      );
                    },
                  ),
                  const Divider(height: 1),
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
                      final reminders = context.read<DebtSmsReminderService>();
                      await notifications.runDebtChecks();
                      final result = await reminders.processReminders();
                      await reminders.processRetryQueue();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Done. SMS sent: ${result.sent}'),
                          ),
                        );
                      }
                    },
                  ),
                ],
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
