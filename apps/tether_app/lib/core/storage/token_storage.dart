import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_factory.dart';

/// Persistencia de los tokens de sesión (Keychain/Keystore por plataforma).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? createSecureStorage();

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? _accessCache;

  /// Access token en memoria (evita lecturas síncronas del keychain).
  String? get accessToken => _accessCache;

  Future<String?> readAccessToken() async {
    final value = await _storage.read(key: _kAccess);
    if (value != null) {
      _accessCache = value;
    }
    return value;
  }

  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessCache = access;
    await Future.wait([
      _storage.write(key: _kAccess, value: access),
      _storage.write(key: _kRefresh, value: refresh),
    ]);
  }

  Future<void> clear() async {
    _accessCache = null;
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
    ]);
  }
}
