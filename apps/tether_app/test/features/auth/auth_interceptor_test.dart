import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tether_app/core/api/api_client.dart';
import 'package:tether_app/core/api/endpoints.dart';

import '../../helpers/memory_token_storage.dart';

void main() {
  late MemoryTokenStorage storage;
  late Dio dio;
  late Dio refreshDio;
  late _FakeRefreshServer refreshServer;

  setUp(() {
    storage = MemoryTokenStorage();
    refreshDio = Dio(BaseOptions(baseUrl: 'http://test'));
    refreshServer = _FakeRefreshServer(refreshDio);
    dio = _buildDio(storage, refreshDio);
  });

  tearDown(() {
    dio.close(force: true);
    refreshDio.close(force: true);
  });

  test('inyecta el Bearer token en requests autenticados', () async {
    await storage.saveTokens(access: 'access-token', refresh: 'refresh-token');
    dio = _buildDio(storage, refreshDio);
    var capturedAuth = '';
    dio.httpClientAdapter = _EchoAdapter((options) {
      capturedAuth = options.headers['Authorization'] as String? ?? '';
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {'ok': true},
      );
    });

    await dio.get('/devices');

    expect(capturedAuth, 'Bearer access-token');
  });

  test('no inyecta token en la request de refresh', () async {
    await storage.saveTokens(access: 'access-token', refresh: 'refresh-token');
    dio = _buildDio(storage, refreshDio);
    var capturedAuth = 'unset';
    dio.httpClientAdapter = _EchoAdapter((options) {
      capturedAuth = options.headers['Authorization'] as String? ?? '';
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {'ok': true},
      );
    });

    await dio.get(Endpoints.authRefresh);

    expect(capturedAuth, isEmpty);
  });

  test('en 401 hace refresh y reintenta la request', () async {
    await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');
    dio = _buildDio(storage, refreshDio);

    var refreshCalled = 0;
    refreshServer.onRefresh = (body) {
      refreshCalled++;
      expect(body['refreshToken'], 'old-refresh');
      return {'accessToken': 'new-access', 'refreshToken': 'new-refresh'};
    };

    var requestCount = 0;
    final adapter = _EchoAdapter((options) {
      requestCount++;
      final auth = options.headers['Authorization'] as String? ?? '';
      if (auth == 'Bearer new-access') {
        return Response(requestOptions: options, statusCode: 200, data: {'ok': true});
      }
      return Response(requestOptions: options, statusCode: 401, data: {'message': 'expired'});
    });
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = adapter;

    final res = await dio.get('/devices');

    expect(requestCount, 2);
    expect(refreshCalled, 1);
    expect(res.data, {'ok': true});
    expect(storage.accessToken, 'new-access');
  });

  test('si el refresh falla limpia la sesión y rechaza', () async {
    await storage.saveTokens(access: 'old-access', refresh: 'expired-refresh');
    dio = _buildDio(storage, refreshDio);

    refreshServer.onRefresh = (_) => throw _RefreshFailure();

    dio.httpClientAdapter = _EchoAdapter(
      (_) => Response(
        requestOptions: RequestOptions(path: '/devices'),
        statusCode: 401,
        data: {'message': 'expired'},
      ),
    );

    await expectLater(
      dio.get('/devices'),
      throwsA(isA<DioException>()),
    );
    expect(storage.accessToken, isNull);
    expect(await storage.readRefreshToken(), isNull);
  });
}

class _RefreshFailure implements Exception {}

Dio _buildDio(MemoryTokenStorage storage, Dio refreshDio) {
  final client = Dio(BaseOptions(baseUrl: 'http://test'));
  client.interceptors.add(AuthInterceptor(storage, refreshDio: refreshDio));
  return client;
}

class _EchoAdapter implements HttpClientAdapter {
  _EchoAdapter(this._handler);

  final Response Function(RequestOptions) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _handler(options);
    final body = response.data is String
        ? response.data as String
        : jsonEncode(response.data);
    return ResponseBody.fromString(
      body,
      response.statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeRefreshServer {
  _FakeRefreshServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path == Endpoints.authRefresh) {
            try {
              final body = options.data as Map<String, dynamic>;
              final tokens = onRefresh!(body);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: tokens,
                ),
              );
            } on _RefreshFailure {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 401,
                    data: {'message': 'invalid refresh token'},
                  ),
                ),
              );
            }
            return;
          }
          handler.next(options);
        },
      ),
    );
  }

  dynamic Function(Map<String, dynamic> body)? onRefresh;
}
