import '../domain/file_item.dart';
import 'files_api.dart';

class FilesRepository {
  FilesRepository(this._api);

  final FilesApi _api;

  Future<CreateFileResult> create({
    required String name,
    required int size,
    String? mimeType,
  }) => _api.create(name: name, size: size, mimeType: mimeType);

  Future<List<FileItem>> list({int limit = 50}) => _api.list(limit: limit);

  Future<String> getDownloadUrl(String id) => _api.getDownloadUrl(id);

  Future<FileItem> complete(String id) => _api.complete(id);

  Future<void> delete(String id) => _api.delete(id);
}
