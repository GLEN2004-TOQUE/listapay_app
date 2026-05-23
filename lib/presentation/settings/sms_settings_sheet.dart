import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/core/utils/phone_format.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/data/services/debt_sms_reminder_service.dart';
import 'package:listapay/data/services/sms_service.dart';

class SmsSettingsSheet extends StatefulWidget {
  const SmsSettingsSheet({super.key});

  @override
  State<SmsSettingsSheet> createState() => _SmsSettingsSheetState();
}

class _SmsSettingsSheetState extends State<SmsSettingsSheet> {
  final _apiKeyController = TextEditingController();
  final _senderController = TextEditingController();
  final _testPhoneController = TextEditingController();
  bool _obscureKey = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sms = context.read<SmsService>();
    final apiKey = await sms.getApiKey();
    final sender = await sms.getSenderName();
    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _senderController.text = sender;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _senderController.dispose();
    _testPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final sms = context.read<SmsService>();
    await sms.saveApiKey(_apiKeyController.text);
    await sms.saveSenderName(_senderController.text);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS settings saved.')),
      );
    }
  }

  Future<void> _sendTestSms() async {
    final online = await context.read<ConnectivityService>().isOnline();
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS requires an internet connection.')),
      );
      return;
    }

    final phone = _testPhoneController.text.trim();
    if (normalizePhilippinePhone(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid PH mobile number (09xx).')),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await context.read<SmsService>().sendMessage(
          phone: phone,
          message: 'ListaPay test SMS — your Semaphore setup is working!',
        );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success ? 'Test SMS sent.' : result.errorMessage ?? 'Failed',
          ),
        ),
      );
    }
  }

  Future<void> _runReminders() async {
    setState(() => _saving = true);
    final reminders = context.read<DebtSmsReminderService>();
    final result = await reminders.processReminders();
    final retries = await reminders.processRetryQueue();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SMS sent: ${result.sent + retries.sent}, '
            'queued: ${result.queued}, skipped: ${result.skipped}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Semaphore SMS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'API key is stored encrypted on this device.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'Semaphore API key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _senderController,
                    decoration: const InputDecoration(
                      labelText: 'Sender name',
                      hintText: 'LISTAPAY',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _testPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Test phone (09xx)',
                      prefixText: '+63 ',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Save settings'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : _sendTestSms,
                    child: const Text('Send test SMS'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : _runReminders,
                    child: const Text('Send debt reminders now'),
                  ),
                ],
              ),
            ),
    );
  }
}
