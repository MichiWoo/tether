/// Configuración global de la app.
///
/// Se puede sobreescribir en tiempo de compilación/ejecución con:
///   flutter run --dart-define=API_BASE_URL=https://api.tether.app
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3100',
  );

  static const String realtimePath = '/realtime';
}
