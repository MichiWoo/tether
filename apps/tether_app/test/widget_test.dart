import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tether_app/app.dart';
import 'package:tether_app/core/storage/token_storage.dart';
import 'package:tether_app/features/auth/providers/auth_provider.dart';

/// TokenStorage en memoria para tests (evita el plugin de keychain).
class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage({String? access}) : _access = access;

  String? _access;
  String? _refresh;

  @override
  String? get accessToken => _access;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

void main() {
  setUp(() {
    // Evita que google_fonts intente descargar fuentes en el test.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('sin sesión muestra la pantalla de inicio de sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
        ],
        child: const TetherApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tether'), findsOneWidget);
    expect(find.text('Conecta tus dispositivos'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
