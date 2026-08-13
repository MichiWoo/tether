import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late AuthController controller;

  setUp(() {
    repository = FakeAuthRepository();
    controller = AuthController(repository);
  });

  tearDown(() => controller.dispose());

  group('bootstrap', () {
    test('restaura la sesión y queda autenticado', () async {
      await controller.bootstrap();
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.email, 'a@b.com');
    });

    test('sin sesión válida queda unauthenticated', () async {
      repository.return401 = true;
      await controller.bootstrap();
      expect(controller.state.status, AuthStatus.unauthenticated);
    });

    test('error de red conserva tokens y queda offline', () async {
      repository.networkError = true;
      await controller.bootstrap();
      expect(controller.state.status, AuthStatus.offline);
      expect(controller.state.error, isNotNull);
    });
  });

  group('login', () {
    test('autentica y expone el usuario', () async {
      await controller.login(email: 'a@b.com', password: '12345678');
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.email, 'a@b.com');
      expect(repository.loginCalls, 1);
    });

    test('error 401 expone mensaje amigable', () async {
      repository.failLogin = true;
      await controller.login(email: 'a@b.com', password: 'wrong');
      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.error, 'Credenciales inválidas');
    });

    test('error de red expone mensaje de conexión', () async {
      repository.networkError = true;
      await controller.login(email: 'a@b.com', password: '12345678');
      expect(controller.state.error, contains('No se pudo conectar'));
    });
  });

  group('register', () {
    test('registra y autentica', () async {
      await controller.register(
        email: 'a@b.com',
        password: '12345678',
        name: 'Ana',
      );
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.name, 'Ana');
      expect(repository.registerCalls, 1);
    });

    test('error con lista de mensajes los une', () async {
      repository.failRegister = true;
      await controller.register(
        email: 'a@b.com',
        password: '12345678',
      );
      expect(controller.state.error, 'Email ya registrado');
    });
  });

  group('logout', () {
    test('cierra sesión', () async {
      await controller.login(email: 'a@b.com', password: '12345678');
      await controller.logout();
      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(repository.logoutCalls, 1);
    });
  });

  group('clearError', () {
    test('limpia el error conservando el estado', () async {
      repository.failLogin = true;
      await controller.login(email: 'a@b.com', password: 'wrong');
      expect(controller.state.error, isNotNull);

      controller.clearError();
      expect(controller.state.error, isNull);
      expect(controller.state.status, AuthStatus.unauthenticated);
    });
  });
}
