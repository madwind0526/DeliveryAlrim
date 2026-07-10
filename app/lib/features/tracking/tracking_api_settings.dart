import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/secure_credentials.dart';

final sweettrackerKeyStoreProvider = Provider<SweettrackerKeyStore>(
  (ref) => SweettrackerKeyStore(ref.watch(secureStorageProvider)),
);

final trackingQuotaStoreProvider = Provider<DailyQuotaStore>(
  (ref) => DailyQuotaStore(ref.watch(secureStorageProvider)),
);

/// Sweet Tracker API key, encrypted at rest like all external credentials.
/// No key registered = the whole active-query feature stays off.
class SweettrackerKeyStore {
  static const _key = 'tracking_api.sweettracker.key';

  final FlutterSecureStorage _storage;

  const SweettrackerKeyStore(this._storage);

  Future<String?> read() async {
    try {
      final value = await _storage.read(key: _key);
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String apiKey) async {
    try {
      await _storage.write(key: _key, value: apiKey);
    } catch (_) {
      return;
    }
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      return;
    }
  }
}

/// Daily call budget for the Sweet Tracker free tier (~100 calls/day).
/// Persisted as 'yyyy-MM-dd:count'; the counter resets when the date
/// rolls over. Consume-before-call so failed responses still count —
/// the provider bills the request either way.
class DailyQuotaStore {
  static const defaultDailyLimit = 100;
  static const _key = 'tracking_api.sweettracker.quota';

  final FlutterSecureStorage _storage;
  final int dailyLimit;
  final DateTime Function() _now;

  DailyQuotaStore(
    this._storage, {
    this.dailyLimit = defaultDailyLimit,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String _todayKey() {
    final d = _now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<int> usedToday() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (_) {
      return 0;
    }
    if (raw == null) return 0;
    final sep = raw.lastIndexOf(':');
    if (sep < 0) return 0;
    if (raw.substring(0, sep) != _todayKey()) return 0;
    return int.tryParse(raw.substring(sep + 1)) ?? 0;
  }

  /// Reserves one call. Returns false (without consuming) when today's
  /// budget is exhausted.
  Future<bool> tryConsume() async {
    final used = await usedToday();
    if (used >= dailyLimit) return false;
    try {
      await _storage.write(key: _key, value: '${_todayKey()}:${used + 1}');
    } catch (_) {
      // Storage failure: allow the call rather than blocking the feature;
      // the server enforces the hard limit anyway.
    }
    return true;
  }
}
