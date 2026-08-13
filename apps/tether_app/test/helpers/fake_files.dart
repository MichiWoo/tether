import 'dart:async';

import 'package:dio/dio.dart';
import 'package:tether_app/features/files/data/files_api.dart';
import 'package:tether_app/features/files/data/files_repository.dart';
import 'package:tether_app/features/files/data/shares_api.dart';
import 'package:tether_app/features/files/data/shares_repository.dart';
import 'package:tether_app/features/files/data/upload_service.dart';
import 'package:tether_app/features/files/domain/file_item.dart';
import 'package:tether_app/features/files/domain/share.dart';

/// FilesRepository con comportamiento controlado para tests.
class FakeFilesRepository extends FilesRepository {
  FakeFilesRepository() : super(FakeFilesApi());

  final List<FileItem> files = [];
  bool failLoad = false;
  bool failComplete = false;
  String? downloadUrl = 'https://example.com/file.bin';
  int deleteCalls = 0;
  int completeCalls = 0;

  @override
  Future<CreateFileResult> create({
    required String name,
    required int size,
    String? mimeType,
  }) async {
    final file = FileItem(
      id: 'f${files.length + 1}',
      name: name,
      size: size,
      mimeType: mimeType,
      status: FileStatus.pending,
      createdAt: DateTime.now(),
    );
    files.add(file);
    return CreateFileResult(
      file: file,
      uploadUrl: 'https://upload.example.com/$name',
      uploadContentType: mimeType ?? 'application/octet-stream',
    );
  }

  @override
  Future<List<FileItem>> list({int limit = 50}) async {
    if (failLoad) throw StateError('boom');
    return List.of(files);
  }

  @override
  Future<String> getDownloadUrl(String id) async {
    if (downloadUrl == null) throw StateError('no url');
    return downloadUrl!;
  }

  @override
  Future<FileItem> complete(String id) async {
    completeCalls++;
    if (failComplete) throw StateError('boom');
    final existing = _find(id);
    final base = existing ??
        FileItem(
          id: id,
          name: 'archivo',
          size: 1,
          mimeType: 'application/octet-stream',
          status: FileStatus.pending,
          createdAt: DateTime.now(),
        );
    final uploaded = FileItem(
      id: base.id,
      name: base.name,
      size: base.size,
      mimeType: base.mimeType,
      status: FileStatus.uploaded,
      uploadedAt: DateTime.now(),
      createdAt: base.createdAt,
    );
    if (existing != null) {
      final index = files.indexWhere((f) => f.id == id);
      files[index] = uploaded;
    }
    return uploaded;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    files.removeWhere((f) => f.id == id);
  }

  FileItem? _find(String id) {
    for (final f in files) {
      if (f.id == id) return f;
    }
    return null;
  }
}

class FakeFilesApi extends FilesApi {
  FakeFilesApi() : super(Dio());
}

/// UploadService sin red: registra llamadas y reporta progreso.
class FakeUploadService extends UploadService {
  FakeUploadService() : super();

  final List<String> uploadedPaths = [];
  final List<String> downloadedUrls = [];
  bool failUpload = false;
  bool failDownload = false;
  Completer<void>? downloadGate;
  final List<double> progressReports = [];

  @override
  Future<void> upload({
    required String url,
    required String path,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (failUpload) {
      throw DioException(requestOptions: RequestOptions(path: url));
    }
    uploadedPaths.add(path);
    onProgress?.call(0.5);
    onProgress?.call(1.0);
  }

  @override
  Future<void> download({
    required String url,
    required String savePath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (failDownload) {
      throw DioException(requestOptions: RequestOptions(path: url));
    }
    if (downloadGate != null) {
      await downloadGate!.future;
    }
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.cancel,
      );
    }
    downloadedUrls.add(url);
    onProgress?.call(0.5);
    onProgress?.call(1.0);
  }

  String? textContent;
  bool failFetchText = false;

  @override
  Future<String> fetchText(String url) async {
    if (failFetchText) {
      throw DioException(requestOptions: RequestOptions(path: url));
    }
    return textContent ?? '';
  }
}

/// SharesRepository con comportamiento controlado para tests.
class FakeSharesRepository extends SharesRepository {
  FakeSharesRepository() : super(FakeSharesApi());

  final List<Share> shares = [];
  bool failLoad = false;
  String? downloadUrl = 'https://example.com/share.bin';
  int cancelCalls = 0;

  @override
  Future<Share> create({
    required String fileId,
    String? targetDeviceId,
    String? senderDeviceId,
  }) async {
    final share = _build(
      's${shares.length + 1}',
      status: ShareStatus.created,
      senderDeviceId: senderDeviceId ?? 'local',
      targetDeviceId: targetDeviceId,
    );
    shares.insert(0, share);
    return share;
  }

  @override
  Future<List<Share>> list({String? status}) async {
    if (failLoad) throw StateError('boom');
    return List.of(shares);
  }

  @override
  Future<String?> getDownloadUrl(String id) async => downloadUrl;

  @override
  Future<Share> accept(String id) async => _updateStatus(id, ShareStatus.accepted, acceptedAt: true);

  @override
  Future<Share> downloaded(String id) async => _updateStatus(id, ShareStatus.downloaded, downloadedAt: true);

  @override
  Future<Share> cancel(String id) async {
    cancelCalls++;
    final share = _updateStatus(id, ShareStatus.expired);
    return share;
  }

  Share _updateStatus(String id, ShareStatus status, {bool acceptedAt = false, bool downloadedAt = false}) {
    final index = shares.indexWhere((s) => s.id == id);
    final current = shares[index];
    final updated = Share(
      id: current.id,
      status: status,
      file: current.file,
      senderDeviceId: current.senderDeviceId,
      targetDeviceId: current.targetDeviceId,
      acceptedAt: acceptedAt ? DateTime.now() : current.acceptedAt,
      downloadedAt: downloadedAt ? DateTime.now() : current.downloadedAt,
      expiresAt: current.expiresAt,
      createdAt: current.createdAt,
    );
    shares[index] = updated;
    return updated;
  }
}

class FakeSharesApi extends SharesApi {
  FakeSharesApi() : super(Dio());
}

Share _build(String id, {required ShareStatus status, String? senderDeviceId, String? targetDeviceId}) => Share(
      id: id,
      status: status,
      file: FileItem(
        id: 'file-$id',
        name: 'documento.pdf',
        size: 2048,
        mimeType: 'application/pdf',
        status: FileStatus.uploaded,
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      senderDeviceId: senderDeviceId,
      targetDeviceId: targetDeviceId,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

/// Construye un share listo para pruebas de UI.
Share makeShare({
  String id = 's1',
  ShareStatus status = ShareStatus.created,
  String? senderDeviceId = 'otro',
  String? targetDeviceId,
  String fileName = 'documento.pdf',
}) => Share(
      id: id,
      status: status,
      file: FileItem(
        id: 'file-$id',
        name: fileName,
        size: 2048,
        mimeType: 'application/pdf',
        status: FileStatus.uploaded,
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      senderDeviceId: senderDeviceId,
      targetDeviceId: targetDeviceId,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

FileItem makeFileItem({
  String id = 'f1',
  String name = 'informe.pdf',
  int size = 1024,
  FileStatus status = FileStatus.uploaded,
  String? mimeType = 'application/pdf',
}) => FileItem(
      id: id,
      name: name,
      size: size,
      mimeType: mimeType,
      status: status,
      uploadedAt: status == FileStatus.uploaded ? DateTime.now() : null,
      createdAt: DateTime.now(),
    );