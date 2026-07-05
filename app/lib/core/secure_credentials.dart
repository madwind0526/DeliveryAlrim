import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => SecureCredentialStore(ref.watch(secureStorageProvider)),
);

enum CredentialSource {
  gmail('gmail'),
  otherEmail('other_email'),
  kakao('kakao'),
  telegram('telegram'),
  whatsapp('whatsapp');

  final String code;
  const CredentialSource(this.code);
}

class SourceCredential {
  final String account;
  final String secret;

  const SourceCredential({required this.account, required this.secret});
}

abstract interface class CredentialStore {
  Future<SourceCredential?> read(CredentialSource source);
  Future<void> write(CredentialSource source, SourceCredential credential);
  Future<void> delete(CredentialSource source);
}

class SecureCredentialStore implements CredentialStore {
  final FlutterSecureStorage _storage;

  const SecureCredentialStore(this._storage);

  @override
  Future<SourceCredential?> read(CredentialSource source) async {
    final account = await _storage.read(key: _key(source, 'account'));
    final secret = await _storage.read(key: _key(source, 'secret'));
    if (account == null || secret == null) return null;
    return SourceCredential(account: account, secret: secret);
  }

  @override
  Future<void> write(
    CredentialSource source,
    SourceCredential credential,
  ) async {
    await _storage.write(
      key: _key(source, 'account'),
      value: credential.account,
    );
    await _storage.write(key: _key(source, 'secret'), value: credential.secret);
  }

  @override
  Future<void> delete(CredentialSource source) async {
    await _storage.delete(key: _key(source, 'account'));
    await _storage.delete(key: _key(source, 'secret'));
  }

  String _key(CredentialSource source, String field) =>
      'credential.${source.code}.$field';
}
