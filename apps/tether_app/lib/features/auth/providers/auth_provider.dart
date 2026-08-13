import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../domain/models.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated, offline }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final User? user;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading =>
      status == AuthStatus.unknown || status == AuthStatus.authenticating;
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(tokenStorageProvider),
  ),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
      (ref) => AuthController(ref.watch(authRepositoryProvider)),
    );

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository)
    : super(const AuthState(status: AuthStatus.unknown));

  final AuthRepository _repository;

  /// Restaura la sesión guardada al arrancar la app.
  ///
  /// Un error de red (servidor caído) conserva la sesión en estado `offline`
  /// en vez de descartar los tokens: el usuario podrá reintentar sin perder
  /// la sesión guardada. Solo un 401 real limpia la sesión.
  Future<void> bootstrap() async {
    try {
      final user = await _repository.restoreSession();
      state = user == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        state = AuthState(status: AuthStatus.offline, error: _friendlyError(e));
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _authenticate(
      () => _repository.login(email: email, password: password),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    await _authenticate(
      () => _repository.register(email: email, password: password, name: name),
    );
  }

  Future<void> retryBootstrap() => bootstrap();

  void clearError() {
    if (state.error == null) return;
    state = AuthState(status: state.status, user: state.user);
  }

  Future<void> _authenticate(Future<AuthResult> Function() action) async {
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final result = await action();
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } on DioException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  bool _isNetworkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  String _friendlyError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
    }
    if (_isNetworkError(e)) {
      return 'No se pudo conectar con el servidor. Verifica que el backend esté corriendo en ${e.requestOptions.baseUrl}.';
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}
