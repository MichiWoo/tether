import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Devuelve un `FlutterSecureStorage` apto para desarrollo/firma ad-hoc.
///
/// Por defecto el plugin usa la *Data Protection Keychain* de macOS
/// (`useDataProtectionKeyChain: true`), que exige un application-identifier
/// (firma con equipo de desarrollo). Con firma ad-hoc falla con
/// `errSecMissingEntitlement` (-34018). Desactivarla usa el keychain
/// convencional y funciona sin equipo.
FlutterSecureStorage createSecureStorage() => const FlutterSecureStorage(
      mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    );
