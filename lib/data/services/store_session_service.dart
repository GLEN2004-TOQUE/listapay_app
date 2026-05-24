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

/// Supabase device session for cloud sync. Cashiers still use local PIN auth.
class StoreSessionService {
  StoreSessionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storeIdKey = 'sync_store_id';
  static const _storeNameKey = 'sync_store_name';
  static const _deviceLabelKey = 'sync_device_label';

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

  Future<bool> hasSupabaseSession() async {
    return _client.auth.currentSession != null;
  }

  Future<void> ensureSupabaseAuth() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
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

    final result = await _client.rpc(
      'pair_store_device',
      params: params,
    );

    if (result is! Map) {
      throw const StoreSessionException('Unexpected response from server.');
    }

    final storeId = result['store_id']?.toString();
    final storeName = result['store_name']?.toString();
    if (storeId == null || storeName == null) {
      throw const StoreSessionException('Pairing failed — invalid server response.');
    }

    await _storage.write(key: _storeIdKey, value: storeId);
    await _storage.write(key: _storeNameKey, value: storeName);
    await _storage.write(key: _deviceLabelKey, value: label);

    await _client.auth.refreshSession();

    return StoreSession(
      storeId: storeId,
      storeName: storeName,
      deviceLabel: label,
    );
  }

  Future<void> unpair() async {
    await _storage.delete(key: _storeIdKey);
    await _storage.delete(key: _storeNameKey);
    await _storage.delete(key: _deviceLabelKey);
    await _client.auth.signOut();
  }

  Future<void> restoreSessionIfNeeded() async {
    final paired = await isPaired();
    if (!paired) return;

    if (_client.auth.currentSession == null) {
      await ensureSupabaseAuth();
    }

    final storeId = await _storage.read(key: _storeIdKey);
    if (storeId == null) return;

    final jwtStoreId =
        _client.auth.currentSession?.user.appMetadata['store_id'];
    if (jwtStoreId == storeId) return;

    debugPrint('ListaPay: stored store not in JWT; re-pair required.');
  }
}

class StoreSessionException implements Exception {
  const StoreSessionException(this.message);
  final String message;

  @override
  String toString() => message;
}
