import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../domain/models.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

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

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<Dio>(
  (ref) => ApiClient.create(storage: ref.watch(tokenStorageProvider)),
);

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
  Future<void> bootstrap() async {
    try {
      final user = await _repository.restoreSession();
      state = user == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String email, required String password}) =>
      _authenticate(() => _repository.login(email: email, password: password));

  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) =>
      _authenticate(
        () => _repository.register(email: email, password: password, name: name),
      );

  Future<bool> _authenticate(Future<AuthResult> Function() action) async {
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final result = await action();
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      return true;
    } on DioException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
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
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'No se pudo conectar con el servidor. Verifica que el backend esté corriendo en ${e.requestOptions.baseUrl}.';
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}
