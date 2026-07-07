import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'constants/couriers.dart';
import 'secure_credentials.dart' show secureStorageProvider;

final courierRegistryProvider = Provider<CourierRegistry>(
  (ref) => CourierRegistry(ref.watch(secureStorageProvider)),
);

/// The user-editable courier list (Settings > 로컬). [courierListProvider]
/// resolves it into real [Courier]s that RuleEngine and every courier
/// picker in the app use, so adding/removing a name here actually changes
/// what gets detected/selectable — not just a display list.
final courierListProvider = FutureProvider<List<Courier>>((ref) async {
  final registry = ref.watch(courierRegistryProvider);
  final names = await registry.readNames();
  return registry.resolveAll(names);
});

class CourierRegistry {
  final FlutterSecureStorage _storage;

  const CourierRegistry(this._storage);

  static const _key = 'courier_registry.names';

  static final List<String> defaultNames = Couriers.all
      .map((c) => c.nameKo)
      .toList();

  Future<List<String>> readNames() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return List.of(defaultNames);
      final decoded = (jsonDecode(raw) as List).cast<String>();
      return decoded.isEmpty ? List.of(defaultNames) : decoded;
    } catch (_) {
      return List.of(defaultNames);
    }
  }

  Future<void> _writeNames(List<String> names) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(names));
    } catch (_) {
      return;
    }
  }

  Future<List<String>> addName(String name) async {
    final names = await readNames();
    final trimmed = name.trim();
    if (trimmed.isEmpty || names.contains(trimmed)) return names;
    final updated = [...names, trimmed];
    await _writeNames(updated);
    return updated;
  }

  Future<List<String>> removeName(String name) async {
    final names = await readNames();
    final updated = names.where((n) => n != name).toList();
    await _writeNames(updated);
    return updated;
  }

  /// Known courier names resolve to their real invoice pattern/tracking
  /// code; unrecognized names get a generic numeric pattern and use the
  /// name itself as the code, so display fallbacks (`byCode(code)?.nameKo
  /// ?? code`) already show the right text without extra plumbing.
  Courier resolve(String name) {
    final builtin = Couriers.all.where((c) => c.nameKo == name);
    if (builtin.isNotEmpty) return builtin.first;
    return Courier(
      code: name,
      nameKo: name,
      sweettrackerCode: null,
      invoicePattern: r'^[0-9\-]{8,20}$',
    );
  }

  List<Courier> resolveAll(List<String> names) =>
      names.map(resolve).toList();
}
