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
  final _storeNameController = TextEditingController();
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
    if (session != null && (pairingCode == null || pairingCode.isEmpty)) {
      await _refreshPairingCode(silent: true);
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _codeController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _createStoreAndPairAdminDevice() async {
    if (!SupabaseConfig.isConfigured) {
      _showMessage('Cloud sync is unavailable because Supabase is not configured.');
      return;
    }

    setState(() => _busy = true);
    final bindingService = context.read<DeviceBindingService>();
    final storeSessionService = context.read<StoreSessionService>();
    final syncService = context.read<SyncService>();
    try {
      final deviceId = await bindingService.currentDeviceId();
      final result = await storeSessionService.createStoreAndPairAdminDevice(
        _storeNameController.text,
        deviceLabel: _labelController.text.trim().isEmpty
            ? 'Admin Device'
            : _labelController.text,
        deviceFingerprint: deviceId,
      );
      if (!mounted) return;
      setState(() {
        _session = result.session;
        _pairingCode = result.pairingCode;
        _labelController.text = result.session.deviceLabel ?? 'Admin Device';
      });
      final syncResult = await syncService.syncNow();
      if (!mounted) return;
      final message = syncResult.skipped || syncResult.message != null
          ? 'Store created and admin device paired. ${syncResult.message ?? 'You can sync after setup.'}'
          : 'Store created and admin device paired. Pairing code is ready to share.';
      _showMessage(message);
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

  Future<void> _pair() async {
    if (!SupabaseConfig.isConfigured) {
      _showMessage('Cloud sync is unavailable because Supabase is not configured.');
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

  Future<void> _refreshPairingCode({bool silent = false}) async {
    if (_session == null) return;
    setState(() => _busy = true);
    try {
      final code = await context.read<StoreSessionService>().fetchPairingCode();
      if (!mounted) return;
      setState(() => _pairingCode = code);
      if (!silent && code != null && code.isNotEmpty) {
        _showMessage('Pairing code refreshed.');
      }
    } on StoreSessionException catch (e) {
      if (!mounted || silent) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotatePairingCode() async {
    setState(() => _busy = true);
    try {
      final code = await context.read<StoreSessionService>().rotatePairingCode();
      if (!mounted) return;
      setState(() => _pairingCode = code);
      _showMessage('Pairing code rotated.');
    } on StoreSessionException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                    'Cloud sync is unavailable because Supabase is not configured '
                    'for this build.\n\n'
                    'Once Supabase is available, pair this admin device to the '
                    'store. After a successful pair, the same pairing code will be '
                    'shown here so you can share it with cashier and inventory '
                    'staff.',
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
                      if (_pairingCode != null && _pairingCode!.isNotEmpty)
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
                        )
                      else
                        Text(
                          'No pairing code is cached on this device yet. Tap Refresh to fetch it from Supabase.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _refreshPairingCode,
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Refresh'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _rotatePairingCode,
                            icon: const Icon(Icons.autorenew_outlined),
                            label: const Text('Rotate'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
                        ? 'If this is the first admin device for a store, create the store here and the app will generate the first pairing code. If the store already exists, you can also pair with an existing code below.\n\nThis requires Supabase Anonymous sign-ins to be enabled in your project.'
                        : 'Pairing is unavailable until cloud sync is configured for this build.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Store name',
                  hintText: 'Create a new store',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Admin device label',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || !configured ? null : _createStoreAndPairAdminDevice,
                icon: _busy
                    ? const BrandedLoadingIndicator(
                        size: 20,
                        strokeWidth: 2,
                        showHalo: false,
                      )
                    : const Icon(Icons.storefront_outlined),
                label: const Text('Create store and pair admin device'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Theme.of(context).dividerColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Or pair an existing store',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Theme.of(context).dividerColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Pairing code',
                  hintText: 'Enter the store pairing code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
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
