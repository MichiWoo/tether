import '../domain/share.dart';
import 'shares_api.dart';

class SharesRepository {
  SharesRepository(this._api);

  final SharesApi _api;

  Future<Share> create({
    required String fileId,
    String? targetDeviceId,
    String? senderDeviceId,
  }) => _api.create(
    fileId: fileId,
    targetDeviceId: targetDeviceId,
    senderDeviceId: senderDeviceId,
  );

  Future<List<Share>> list({String? status}) => _api.list(status: status);

  Future<String?> getDownloadUrl(String id) => _api.getDownloadUrl(id);

  Future<Share> accept(String id) => _api.accept(id);

  Future<Share> downloaded(String id) => _api.downloaded(id);

  Future<Share> cancel(String id) => _api.cancel(id);
}
