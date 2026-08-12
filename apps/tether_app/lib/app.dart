import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/realtime/realtime_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/providers/auth_provider.dart';
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

    // Conecta/desconecta el WebSocket según el estado de sesión.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final realtime = ref.read(realtimeServiceProvider);
      if (next.status == AuthStatus.authenticated) {
        ref
            .read(tokenStorageProvider)
            .readAccessToken()
            .then((token) => realtime.connect(token ?? ''));
      } else if (next.status == AuthStatus.unauthenticated) {
        realtime.disconnect();
      }
    });

    return MaterialApp(
      title: 'Tether',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const _RootGate(),
    );
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
