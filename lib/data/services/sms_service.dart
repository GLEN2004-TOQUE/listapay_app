import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ListaPay/core/utils/phone_format.dart';

class SmsException implements Exception {
  const SmsException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SmsSendResult {
  const SmsSendResult({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;
}

class SmsService {
  SmsService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _apiKeyKey = 'semaphore_api_key';
  static const _senderNameKey = 'semaphore_sender_name';
  static const _defaultSender = 'LISTAPAY';
  static const _apiUrl = 'https://api.semaphore.co/api/v4/messages';

  final FlutterSecureStorage _storage;

  Future<bool> hasApiKey() async {
    final key = await _storage.read(key: _apiKeyKey);
    return key != null && key.trim().isNotEmpty;
  }

  Future<String?> getApiKey() => _storage.read(key: _apiKeyKey);

  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _apiKeyKey);
      return;
    }
    await _storage.write(key: _apiKeyKey, value: trimmed);
  }

  Future<String> getSenderName() async {
    return await _storage.read(key: _senderNameKey) ?? _defaultSender;
  }

  Future<void> saveSenderName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _senderNameKey);
      return;
    }
    await _storage.write(key: _senderNameKey, value: trimmed);
  }

  Future<SmsSendResult> sendMessage({
    required String phone,
    required String message,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const SmsSendResult(
        success: false,
        errorMessage: 'Semaphore API key not configured.',
      );
    }

    final normalized = normalizePhilippinePhone(phone);
    if (normalized == null) {
      return const SmsSendResult(
        success: false,
        errorMessage: 'Invalid Philippine mobile number.',
      );
    }

    final senderName = await getSenderName();

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            body: {
              'apikey': apiKey,
              'number': normalized,
              'message': message,
              'sendername': senderName,
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const SmsSendResult(success: true);
      }

      return SmsSendResult(
        success: false,
        errorMessage: 'Semaphore error (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      return SmsSendResult(
        success: false,
        errorMessage: 'Network error: $e',
      );
    }
  }
}
