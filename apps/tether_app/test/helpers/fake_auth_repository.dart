import 'package:dio/dio.dart';
import 'package:tether_app/core/storage/token_storage.dart';
import 'package:tether_app/features/auth/data/auth_api.dart';
import 'package:tether_app/features/auth/data/auth_repository.dart';
import 'package:tether_app/features/auth/domain/models.dart';

/// AuthRepository con comportamiento controlado para tests.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({TokenStorage? storage})
    : super(FakeAuthApi(), storage ?? FakeTokenStorage());

  bool failLogin = false;
  bool failRegister = false;
  bool networkError = false;
  bool return401 = false;
  int loginCalls = 0;
  int registerCalls = 0;
  int logoutCalls = 0;
  int restoreCalls = 0;

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    loginCalls++;
    if (networkError) throw networkException();
    if (failLogin) throw apiException(status: 401, message: 'Credenciales inválidas');
    return AuthResult(
      tokens: const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      user: User(id: 'u1', email: email),
    );
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    String? name,
  }) async {
    registerCalls++;
    if (networkError) throw networkException();
    if (failRegister) throw apiException(status: 400, message: ['Email ya registrado']);
    return AuthResult(
      tokens: const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      user: User(id: 'u1', email: email, name: name),
    );
  }

  @override
  Future<User?> restoreSession() async {
    restoreCalls++;
    if (networkError) throw networkException();
    if (return401) return null;
    return const User(id: 'u1', email: 'a@b.com');
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class FakeAuthApi extends AuthApi {
  FakeAuthApi() : super(Dio());
}

class FakeTokenStorage extends TokenStorage {
  @override
  String? get accessToken => null;
}

DioException networkException() => DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    );

DioException apiException({required int status, required Object message}) =>
    DioException(
      requestOptions: RequestOptions(path: '/'),
      response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: status,
        data: {'message': message},
      ),
    );
