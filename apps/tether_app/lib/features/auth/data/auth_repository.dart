import 'package:dio/dio.dart';

import '../../../core/storage/token_storage.dart';
import '../domain/models.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final AuthApi _api;
  final TokenStorage _storage;

  Future<AuthResult> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final result = await _api.register(email: email, password: password, name: name);
    await _storage.saveTokens(
      access: result.tokens.accessToken,
      refresh: result.tokens.refreshToken,
    );
    return result;
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final result = await _api.login(email: email, password: password);
    await _storage.saveTokens(
      access: result.tokens.accessToken,
      refresh: result.tokens.refreshToken,
    );
    return result;
  }

  /// Restaura la sesión al abrir la app si existen tokens válidos.
  Future<User?> restoreSession() async {
    final access = await _storage.readAccessToken();
    if (access == null) {
      return null;
    }
    try {
      return await _api.me();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final refresh = await _storage.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // El servidor puede estar caído; aún así limpiamos la sesión local.
      }
    }
    await _storage.clear();
  }
}
