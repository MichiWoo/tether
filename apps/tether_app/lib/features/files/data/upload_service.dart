import 'dart:io';

import 'package:dio/dio.dart';

/// Sube archivos directo a S3/MinIO con la URL presignada (sin pasar por el
/// backend). Usa un `Dio` propio sin interceptor de auth: el PUT a S3 lleva
/// solo los headers firmados.
class UploadService {
  UploadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Sube el archivo [path] a [url] con el [contentType] firmado.
  /// Reporta progreso 0.0–1.0 vía [onProgress].
  Future<void> upload({
    required String url,
    required String path,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(path);
    final length = await file.length();
    final stream = file.openRead();

    await _dio.put<void>(
      url,
      data: stream,
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: length,
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call(sent / total);
        }
      },
    );
  }

  /// Descarga [url] hacia [savePath] usando URL firmada (GET a S3/MinIO).
  /// Reporta progreso 0.0–1.0 vía [onProgress].
  Future<void> download({
    required String url,
    required String savePath,
    void Function(double progress)? onProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received / total);
        }
      },
    );
  }
}
