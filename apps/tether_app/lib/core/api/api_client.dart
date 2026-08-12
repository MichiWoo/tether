import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'endpoints.dart';

/// Se lanza cuando la sesión expiró y el refresh no pudo renovarse.
class SessionExpiredException implements Exception {
  const SessionExpiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Interceptor que inyecta el Bearer token y renueva la sesión en 401
/// (refresh con rotación). Si el refresh falla, limpia la sesión.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {Dio? refreshDio})
      : _refreshDio = refreshDio ?? ApiClient.createRefreshClient();

  final TokenStorage _storage;
  final Dio _refreshDio;
  bool _refreshing = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storage.accessToken;
    final isRefresh = options.path.contains(Endpoints.authRefresh);
    if (token != null && !isRefresh) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final isRefresh = err.requestOptions.path.contains(Endpoints.authRefresh);

    if (status == 401 && !isRefresh && !_refreshing) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
        try {
          final response = await _refreshDio.fetch(options);
          handler.resolve(response);
          return;
        } catch (retryError) {
          handler.reject(retryError as DioException);
          return;
        }
      }
      await _storage.clear();
      handler.reject(err);
      return;
    }

    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) {
      return false;
    }
    _refreshing = true;
    try {
      final res = await _refreshDio.post(
        Endpoints.authRefresh,
        data: {'refreshToken': refreshToken},
      );
      final tokens = res.data as Map<String, dynamic>;
      await _storage.saveTokens(
        access: tokens['accessToken'] as String,
        refresh: tokens['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}

/// Cliente HTTP de la API.
abstract final class ApiClient {
  /// Cliente autenticado con refresh automático ante 401.
  static Dio create({required TokenStorage storage}) {
    final dio = Dio(_baseOptions());
    dio.interceptors.add(AuthInterceptor(storage));
    return dio;
  }

  /// Cliente sin interceptor de auth, para refresh/logout sin recursión.
  static Dio createRefreshClient() => Dio(_baseOptions());

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
}
