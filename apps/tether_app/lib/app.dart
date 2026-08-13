import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/realtime/realtime_provider.dart';
import 'core/storage/storage_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/devices/domain/device.dart';
import 'features/devices/providers/devices_provider.dart';
import 'features/shell/home_shell.dart';

class TetherApp extends ConsumerStatefulWidget {
  const TetherApp({super.key});

  @override
  ConsumerState<TetherApp> createState() => _TetherAppState();
}

class _TetherAppState extends ConsumerState<TetherApp> {
  @override
  void initState() {
    super.initState();
    // Restaura la sesión guardada (tokens en secure storage).
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Tether',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const _Root(),
    );
  }
}

/// Envuelve el gate de autenticación y el bootstrap de dispositivo/realtime.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Stack(
      children: [
        _RootGate(),
        _SessionBootstrap(),
      ],
    );
  }
}

/// Reacciona a los cambios de sesión: conecta el WebSocket, registra e
/// identifica este equipo, y desconecta al cerrar sesión.
class _SessionBootstrap extends ConsumerWidget {
  const _SessionBootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        ref.read(tokenStorageProvider).readAccessToken().then((token) {
          ref.read(realtimeServiceProvider).connect(token ?? '');
        });
        final notifier = ref.read(devicesControllerProvider.notifier);
        notifier.ensureCurrentDevice(
          name: currentPlatform().label,
          platform: currentPlatform(),
        );
      } else if (next.status != AuthStatus.authenticating) {
        ref.read(realtimeServiceProvider).disconnect();
      }
    });
    return const SizedBox.shrink();
  }
}

class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated || auth.user == null) {
      return const AuthScreen();
    }

    return HomeShell(user: auth.user!);
  }
}
