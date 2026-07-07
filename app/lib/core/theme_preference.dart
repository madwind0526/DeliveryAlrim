import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_credentials.dart' show secureStorageProvider;

final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => SecureThemeModeStore(ref.watch(secureStorageProvider)),
);

/// Live theme mode the app root listens to. A plain ValueNotifier (rather
/// than a full state-notifier provider) keeps this consistent with the
/// rest of core/ (Provider-wrapped stores + local widget state).
final themeModeNotifierProvider = Provider<ValueNotifier<ThemeMode>>(
  (ref) => ValueNotifier<ThemeMode>(ThemeMode.dark),
);

abstract interface class ThemeModeStore {
  Future<ThemeMode> read();
  Future<void> write(ThemeMode mode);
}

class SecureThemeModeStore implements ThemeModeStore {
  final FlutterSecureStorage _storage;

  const SecureThemeModeStore(this._storage);

  static const _key = 'app.theme_mode';

  @override
  Future<ThemeMode> read() async {
    try {
      final value = await _storage.read(key: _key);
      return value == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await _storage.write(
        key: _key,
        value: mode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      return;
    }
  }
}
