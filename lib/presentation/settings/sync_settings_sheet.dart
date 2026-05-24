import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/core/config/supabase_config.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/data/services/store_session_service.dart';
import 'package:listapay/data/services/sync_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await context.read<StoreSessionService>().getSession();
    if (mounted) setState(() => _session = session);
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
    try {
      final session = await context.read<StoreSessionService>().pairWithCode(
            _codeController.text,
            deviceLabel: _labelController.text,
          );
      if (mounted) {
        setState(() => _session = session);
        _showMessage('Paired with ${session.storeName}');
      }
    } on StoreSessionException catch (e) {
      _showMessage(e.message);
    } catch (e) {
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cashiers keep using PIN offline. Pair this device once to back up '
              'and sync inventory, customers, sales, and debts.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            if (!configured)
              const Card(
                color: Color(0xFFFFF3E0),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Supabase anon key not set. Run with:\n'
                    'flutter run --dart-define=SUPABASE_ANON_KEY=your_key',
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
              FilledButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Pairing code',
                  hintText: '8-character code from Supabase',
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
