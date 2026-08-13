/// Rutas de la API REST (reflejan el backend NestJS).
abstract final class Endpoints {
  static const authRegister = '/auth/register';
  static const authLogin = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const authMe = '/auth/me';

  static const devices = '/devices';
  static const clipboard = '/clipboard';
  static const clipboardLatest = '/clipboard/latest';
  static const clipboardHistory = '/clipboard/history';
  static const files = '/files';
  static const shares = '/shares';

  static String deviceById(String id) => '/devices/$id';
  static String deviceHeartbeat(String id) => '/devices/$id/heartbeat';
  static String fileById(String id) => '/files/$id';
  static String fileComplete(String id) => '/files/$id/complete';
  static String shareById(String id) => '/shares/$id';
  static String shareAccept(String id) => '/shares/$id/accept';
  static String shareDownloaded(String id) => '/shares/$id/downloaded';
  static String shareCancel(String id) => '/shares/$id/cancel';
}
