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
/// (refresh con rotación). Las requests que fallan con 401 mientras un
/// refresh está en curso esperan a ese mismo refresh y se reintentan. Si el
/// refresh falla, se limpia la sesión y se rechaza.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {Dio? refreshDio})
      : _refreshDio = refreshDio ?? ApiClient.createRefreshClient();

  final TokenStorage _storage;
  final Dio _refreshDio;
  Future<void>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storage.accessToken;
    final isRefresh = options.path == Endpoints.authRefresh;
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
    final isRefresh = err.requestOptions.path == Endpoints.authRefresh;

    if (status != 401 || isRefresh) {
      handler.next(err);
      return;
    }

    await _ensureRefresh();

    if (_storage.accessToken == null || !_lastRefreshOk) {
      await _storage.clear();
      handler.reject(_sessionExpired(err));
      return;
    }

    // Renovamos el token en la request original y la reintentamos.
    final options = err.requestOptions;
    options.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
    try {
      final response = await _refreshDio.fetch(options);
      handler.resolve(response);
    } catch (retryError) {
      handler.reject(retryError as DioException);
    }
  }

  Future<void> _ensureRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  bool _lastRefreshOk = true;

  Future<void> _doRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) {
      _lastRefreshOk = false;
      return;
    }
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
      _lastRefreshOk = true;
    } catch (_) {
      _lastRefreshOk = false;
    }
  }

  DioException _sessionExpired(DioException original) => DioException(
        requestOptions: original.requestOptions,
        response: original.response,
        type: original.type,
        error: const SessionExpiredException(
          'Tu sesión expiró. Inicia sesión de nuevo.',
        ),
      );
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
