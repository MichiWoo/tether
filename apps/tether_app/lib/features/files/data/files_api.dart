import 'package:dio/dio.dart';

import '../../../core/api/endpoints.dart';
import '../domain/file_item.dart';

/// Respuesta de `POST /files`: registro + URL firmada de upload.
class CreateFileResult {
  const CreateFileResult({required this.file, required this.uploadUrl, required this.uploadContentType});

  final FileItem file;
  final String uploadUrl;
  final String uploadContentType;
}

class FilesApi {
  FilesApi(this._dio);

  final Dio _dio;

  Future<CreateFileResult> create({
    required String name,
    required int size,
    String? mimeType,
  }) async {
    final res = await _dio.post(
      Endpoints.files,
      data: {
        'name': name,
        'size': size,
        if (mimeType != null) 'mimeType': mimeType,
      },
    );
    final data = res.data as Map<String, dynamic>;
    final upload = data['upload'] as Map<String, dynamic>;
    final headers = upload['headers'] as Map<String, dynamic>;
    return CreateFileResult(
      file: FileItem.fromJson(data['file'] as Map<String, dynamic>),
      uploadUrl: upload['url'] as String,
      uploadContentType:
          headers['Content-Type'] as String? ?? 'application/octet-stream',
    );
  }

  Future<List<FileItem>> list({int limit = 50}) async {
    final res = await _dio.get<List<dynamic>>(
      Endpoints.files,
      queryParameters: {'limit': limit},
    );
    final items = res.data ?? const [];
    return items
        .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Devuelve la URL firmada de descarga del archivo.
  Future<String> getDownloadUrl(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(Endpoints.fileById(id));
    final data = res.data!;
    return data['downloadUrl'] as String;
  }

  /// Devuelve la URL firmada con disposición inline para previsualizar.
  Future<String> getPreviewUrl(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(Endpoints.filePreview(id));
    final data = res.data!;
    return data['downloadUrl'] as String;
  }

  Future<FileItem> complete(String id) async {
    final res = await _dio.post(Endpoints.fileComplete(id));
    return FileItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete(Endpoints.fileById(id));
  }
}
