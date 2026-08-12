import 'package:dio/dio.dart';

import '../../../core/api/endpoints.dart';
import '../domain/models.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResult> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final res = await _dio.post(
      Endpoints.authRegister,
      data: {
        'email': email.trim(),
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name.trim(),
      },
    );
    return AuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      Endpoints.authLogin,
      data: {'email': email.trim(), 'password': password},
    );
    return AuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> me() async {
    final res = await _dio.get<Map<String, dynamic>>(Endpoints.authMe);
    return User.fromJson(res.data!);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(Endpoints.authLogout, data: {'refreshToken': refreshToken});
  }
}
