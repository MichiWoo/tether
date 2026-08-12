/// Rutas de la API REST (reflejan el backend NestJS).
abstract final class Endpoints {
  static const authRegister = '/auth/register';
  static const authLogin = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const authMe = '/auth/me';

  static const devices = '/devices';
}
