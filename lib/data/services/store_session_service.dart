import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreSession {
  const StoreSession({
    required this.storeId,
    required this.storeName,
    this.deviceLabel,
  });

  final String storeId;
  final String storeName;
  final String? deviceLabel;
}

class StoreSetupResult {
  const StoreSetupResult({
    required this.session,
    required this.pairingCode,
  });

  final StoreSession session;
  final String pairingCode;
}

/// Supabase device session for cloud sync. Cashiers still use local PIN auth.
class StoreSessionService {
  StoreSessionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storeIdKey = 'sync_store_id';
  static const _storeNameKey = 'sync_store_name';
  static const _deviceLabelKey = 'sync_device_label';
  static const _pairingCodeKey = 'sync_pairing_code';

  final FlutterSecureStorage _storage;

  SupabaseClient get _client => Supabase.instance.client;

  Future<StoreSession?> getSession() async {
    final storeId = await _storage.read(key: _storeIdKey);
    if (storeId == null || storeId.isEmpty) return null;

    final storeName = await _storage.read(key: _storeNameKey) ?? 'Store';
    final deviceLabel = await _storage.read(key: _deviceLabelKey);
    return StoreSession(
      storeId: storeId,
      storeName: storeName,
      deviceLabel: deviceLabel,
    );
  }

  Future<bool> isPaired() async => (await getSession()) != null;

  Future<String?> getPairingCode() async {
    final code = await _storage.read(key: _pairingCodeKey);
    if (code == null || code.isEmpty) return null;
    return code;
  }

  Future<bool> hasSupabaseSession() async {
    return _client.auth.currentSession != null;
  }

  Future<void> ensureSupabaseAuth() async {
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously();
    } on AuthApiException catch (e) {
      throw StoreSessionException(_friendlyAuthMessage(e));
    }
  }

  Future<StoreSetupResult> createStoreAndPairAdminDevice(
    String storeName, {
    String? deviceLabel,
    String? deviceFingerprint,
  }) async {
    final trimmedStoreName = storeName.trim();
    if (trimmedStoreName.isEmpty) {
      throw const StoreSessionException('Enter a store name first.');
    }

    await ensureSupabaseAuth();

    final label = (deviceLabel?.trim().isNotEmpty ?? false)
        ? deviceLabel!.trim()
        : 'Admin Device';

    final params = <String, dynamic>{
      'p_store_name': trimmedStoreName,
      'p_device_label': label,
    };
    final fingerprint = deviceFingerprint?.trim();
    if (fingerprint != null && fingerprint.isNotEmpty) {
      params['p_device_fingerprint'] = fingerprint;
    }

    try {
      final result = await _client.rpc(
        'create_store_and_pair_admin_device',
        params: params,
      );
      final parsed = _parseStoreResult(
        result,
        fallbackDeviceLabel: label,
      );
      await _client.auth.refreshSession();
      return parsed;
    } on PostgrestException catch (e) {
      throw StoreSessionException(_friendlyPostgrestMessage(e));
    } catch (e) {
      throw StoreSessionException(e.toString());
    }
  }

  Future<StoreSession> pairWithCode(
    String code, {
    String? deviceLabel,
    String? deviceFingerprint,
  }) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length < 6) {
      throw const StoreSessionException('Enter a valid pairing code.');
    }

    await ensureSupabaseAuth();

    final label = (deviceLabel?.trim().isNotEmpty ?? false)
        ? deviceLabel!.trim()
        : 'POS Device';

    final params = <String, dynamic>{
      'p_code': trimmed,
      'p_device_label': label,
    };
    final fingerprint = deviceFingerprint?.trim();
    if (fingerprint != null && fingerprint.isNotEmpty) {
      params['p_device_fingerprint'] = fingerprint;
    }

    try {
      final result = await _client.rpc(
        'pair_store_device',
        params: params,
      );
      final parsed = await _parseStoreResult(
        result,
        fallbackDeviceLabel: label,
        fallbackPairingCode: trimmed,
      );
      await _client.auth.refreshSession();
      return parsed.session;
    } on PostgrestException catch (e) {
      throw StoreSessionException(_friendlyPostgrestMessage(e));
    } catch (e) {
      if (e is StoreSessionException) rethrow;
      throw StoreSessionException(e.toString());
    }
  }

  Future<String?> fetchPairingCode() async {
    final session = await getSession();
    if (session == null) return null;

    await ensureSupabaseAuth();

    try {
      final result = await _client.rpc('get_current_store_pairing_code');
      final parsed = await _parseStoreResult(
        result,
        fallbackDeviceLabel: session.deviceLabel ?? 'POS Device',
      );
      return parsed.pairingCode;
    } on PostgrestException catch (e) {
      throw StoreSessionException(_friendlyPostgrestMessage(e));
    } catch (e) {
      if (e is StoreSessionException) rethrow;
      throw StoreSessionException(e.toString());
    }
  }

  Future<String> rotatePairingCode() async {
    final session = await getSession();
    if (session == null) {
      throw const StoreSessionException('Pair this device to a store first.');
    }

    await ensureSupabaseAuth();

    try {
      final result = await _client.rpc('rotate_current_store_pairing_code');
      final parsed = await _parseStoreResult(
        result,
        fallbackDeviceLabel: session.deviceLabel ?? 'POS Device',
      );
      return parsed.pairingCode;
    } on PostgrestException catch (e) {
      throw StoreSessionException(_friendlyPostgrestMessage(e));
    } catch (e) {
      if (e is StoreSessionException) rethrow;
      throw StoreSessionException(e.toString());
    }
  }

  Future<void> unpair() async {
    await _storage.delete(key: _storeIdKey);
    await _storage.delete(key: _storeNameKey);
    await _storage.delete(key: _deviceLabelKey);
    await _storage.delete(key: _pairingCodeKey);
    await _client.auth.signOut();
  }

  Future<void> restoreSessionIfNeeded() async {
    final paired = await isPaired();
    if (!paired) return;

    if (_client.auth.currentSession == null) {
      try {
        await ensureSupabaseAuth();
      } on StoreSessionException catch (e) {
        debugPrint('ListaPay: $e');
        return;
      }
    }

    final storeId = await _storage.read(key: _storeIdKey);
    if (storeId == null) return;

    final jwtStoreId =
        _client.auth.currentSession?.user.appMetadata['store_id'];
    if (jwtStoreId == storeId) return;

    debugPrint('ListaPay: stored store not in JWT; re-pair required.');
  }

  Future<StoreSetupResult> _parseStoreResult(
    dynamic result, {
    required String fallbackDeviceLabel,
    String? fallbackPairingCode,
  }) async {
    final row = _extractStoreRow(result);

    final storeId = row['store_id']?.toString();
    final storeName = row['store_name']?.toString();
    final pairingCode =
        row['pairing_code']?.toString() ??
        row['code']?.toString() ??
        fallbackPairingCode;
    if (storeId == null || storeName == null) {
      throw const StoreSessionException('Store setup failed — invalid server response.');
    }

    await _storage.write(key: _storeIdKey, value: storeId);
    await _storage.write(key: _storeNameKey, value: storeName);
    await _storage.write(key: _deviceLabelKey, value: fallbackDeviceLabel);
    if (pairingCode != null && pairingCode.isNotEmpty) {
      await _storage.write(key: _pairingCodeKey, value: pairingCode);
    }

    return StoreSetupResult(
      session: StoreSession(
        storeId: storeId,
        storeName: storeName,
        deviceLabel: fallbackDeviceLabel,
      ),
      pairingCode: pairingCode ?? '',
    );
  }

  Map<String, dynamic> _extractStoreRow(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) {
      return result.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    if (result is List) {
      if (result.isEmpty) {
        throw const StoreSessionException('No store data was returned by Supabase.');
      }
      return _extractStoreRow(result.first);
    }
    throw const StoreSessionException('Unexpected response from server.');
  }

  String _friendlyPostgrestMessage(PostgrestException error) {
    final message = error.message.trim();
    final lower = message.toLowerCase();
    if (lower.contains('created_by_auth_user_id') ||
        (lower.contains('column') && lower.contains('stores'))) {
      return 'Your Supabase pairing schema is incomplete. Re-run the SQL setup '
          'script so the missing columns/functions are added to the existing '
          'tables, then restart the app and try again.';
    }
    if (message.isEmpty) {
      return 'The store request failed on Supabase.';
    }
    return message;
  }

  String _friendlyAuthMessage(AuthApiException error) {
    if (error.code == 'anonymous_provider_disabled' || error.statusCode == '422') {
      return 'Supabase Anonymous sign-ins are disabled for this project. '
          'Open Supabase Dashboard -> Authentication -> Providers -> Anonymous, '
          'enable it, save, then restart the app and try again.';
    }

    if (error.statusCode == '401') {
      return 'Supabase rejected the API key. Update the app with the latest '
          'SUPABASE_ANON_KEY, restart it, then try again.';
    }

    final message = error.message.trim();
    if (message.isNotEmpty) return message;
    return 'Supabase authentication failed while preparing cloud sync.';
  }
}

class StoreSessionException implements Exception {
  const StoreSessionException(this.message);
  final String message;

  @override
  String toString() => message;
}
