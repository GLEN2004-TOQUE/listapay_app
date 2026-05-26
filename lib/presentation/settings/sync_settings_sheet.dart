import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ListaPay/core/config/supabase_config.dart';
import 'package:ListaPay/core/security/device_binding_service.dart';
import 'package:ListaPay/core/theme/app_theme.dart';
import 'package:ListaPay/core/widgets/simple_loading.dart';
import 'package:ListaPay/data/services/store_session_service.dart';
import 'package:ListaPay/data/services/sync_service.dart';

class SyncSettingsSheet extends StatefulWidget {
  const SyncSettingsSheet({super.key});

  @override
  State<SyncSettingsSheet> createState() => _SyncSettingsSheetState();
}

class _SyncSettingsSheetState extends State<SyncSettingsSheet> {
  final _codeController = TextEditingController();
  final _labelController = TextEditingController(text: 'POS Device');
  bool _busy = false;
  StoreSession? _session;
  String? _pairingCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<StoreSessionService>();
    final session = await service.getSession();
    final pairingCode = await service.getPairingCode();
    if (mounted) {
      setState(() {
        _session = session;
        _pairingCode = pairingCode;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    if (!SupabaseConfig.isConfigured) {
      _showMessage('Set SUPABASE_ANON_KEY when running the app.');
      return;
    }

    setState(() => _busy = true);
    final bindingService = context.read<DeviceBindingService>();
    final storeSessionService = context.read<StoreSessionService>();
    final syncService = context.read<SyncService>();
    try {
      final deviceId = await bindingService.currentDeviceId();
      final session = await storeSessionService.pairWithCode(
        _codeController.text,
        deviceLabel: _labelController.text,
        deviceFingerprint: deviceId,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _pairingCode = _codeController.text.trim().toUpperCase();
      });
      final result = await syncService.syncNow();
      if (!mounted) return;
      if (result.skipped || result.message != null) {
        _showMessage(
          'Paired with ${session.storeName}. '
          '${result.message ?? 'Run Sync now to pull store data.'}',
        );
      } else {
        _showMessage(
          'Paired with ${session.storeName}. '
          'Pulled ${result.pulled} store updates.',
        );
      }
    } on StoreSessionException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair() async {
    setState(() => _busy = true);
    try {
      await context.read<StoreSessionService>().unpair();
      if (mounted) {
        setState(() => _session = null);
        _showMessage('Cloud sync disconnected.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final result = await context.read<SyncService>().syncNow();
      if (!mounted) return;
      if (result.skipped) {
        _showMessage(result.message ?? 'Sync skipped');
      } else if (result.message != null) {
        _showMessage(result.message!);
      } else {
        _showMessage(
          'Synced — pushed ${result.pushed}, pulled ${result.pulled}, '
          'deleted ${result.deleted}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copyPairingCode() async {
    final code = _pairingCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _showMessage('Pairing code copied.');
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseConfig.isConfigured;
    final paired = _session != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cloud sync',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Cashiers keep using PIN offline. Pair this device once to back up '
              'and sync inventory, customers, sales, and debts.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (!configured)
              Card(
                color: Color(0xFFFFF3E0),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Cloud sync is not configured on this build yet.\n\n'
                    'Use the Supabase-enabled run configuration first, then pair '
                    'this admin device to the store. After a successful pair, the '
                    'same pairing code will be shown here so you can share it with '
                    'cashier and inventory staff.',
                  ),
                ),
              ),
            if (paired) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.store, color: AppColors.primary),
                title: Text(_session!.storeName),
                subtitle: Text('Store ID: ${_session!.storeId}'),
              ),
              if (_pairingCode != null) ...[
                const SizedBox(height: 8),
                Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current pairing code',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Share this same code with Cashier and Inventory Staff when they register or pair their devices.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _pairingCode!,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _copyPairingCode,
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copy'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: _busy
                    ? const BrandedLoadingIndicator(
                        size: 18,
                        strokeWidth: 2,
                        showHalo: false,
                      )
                    : const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _unpair,
                child: const Text('Disconnect'),
              ),
            ] else ...[
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    configured
                        ? 'If you are the admin, enter the store pairing code once here. '
                            'After this device is paired, the same code will appear in this screen for sharing with cashier and inventory staff.'
                        : 'Pairing is unavailable until cloud sync is configured for this build.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Pairing code',
                  hintText: 'Enter the store pairing code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Device label',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || !configured ? null : _pair,
                child: _busy
                    ? const BrandedLoadingIndicator(
                        size: 20,
                        strokeWidth: 2,
                        showHalo: false,
                      )
                    : const Text('Pair device'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
