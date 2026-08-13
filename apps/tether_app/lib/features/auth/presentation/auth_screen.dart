import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

enum _AuthMode { login, register }

/// Pantalla de autenticación: login y registro con identidad "Constellation"
/// (el hilo que conecta tus dispositivos).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _emailError = null;
      _passwordError = null;
    });
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    ref.read(authControllerProvider.notifier).clearError();
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Ingresa tu email'
          : (!email.contains('@') || !email.contains('.'))
              ? 'Email no válido'
              : null;
      _passwordError = password.length < 8 ? 'Mínimo 8 caracteres' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_mode == _AuthMode.login) {
      await controller.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      await controller.register(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final isLogin = _mode == _AuthMode.login;

    final bg = scheme.background;
    final topTint = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.08),
      bg,
    );
    final bottomTint = Color.alphaBlend(
      scheme.secondary.withValues(alpha: 0.06),
      bg,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topTint, bg, bottomTint],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _ConstellationBackground()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _AuthCard(
                  isLogin: isLogin,
                  authLoading: auth.isLoading,
                  emailError: _emailError,
                  passwordError: _passwordError,
                  serverError: auth.error,
                  offline: auth.status == AuthStatus.offline,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  nameController: _nameController,
                  onModeChanged: _setMode,
                  onSubmit: _submit,
                  onRetry: () => ref
                      .read(authControllerProvider.notifier)
                      .retryBootstrap(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isLogin,
    required this.authLoading,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.onModeChanged,
    required this.onSubmit,
    required this.onRetry,
    this.emailError,
    this.passwordError,
    this.serverError,
    this.offline = false,
  });

  final bool isLogin;
  final bool authLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final ValueChanged<_AuthMode> onModeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final String? emailError;
  final String? passwordError;
  final String? serverError;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.10),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandMark(scheme: scheme),
          const SizedBox(height: 12),
          Text(
            'Conecta tus dispositivos',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.mutedForeground),
          ),
          const SizedBox(height: 28),
          _ModeToggle(isLogin: isLogin, onChanged: onModeChanged),
          const SizedBox(height: 24),
          if (!isLogin) ...[
            const _FieldLabel('Nombre'),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              hintText: 'Nombre (opcional)',
              features: const [
                InputFeature.leading(Icon(LucideIcons.user)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const _FieldLabel('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: emailController,
            hintText: 'tú@ejemplo.com',
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            features: const [
              InputFeature.leading(Icon(LucideIcons.mail)),
            ],
            onSubmitted: (_) => onSubmit(),
          ),
          if (emailError != null) ...[
            const SizedBox(height: 6),
            _FieldError(message: emailError!),
          ],
          const SizedBox(height: 16),
          const _FieldLabel('Contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: passwordController,
            hintText: '••••••••',
            autofillHints: const [AutofillHints.password],
            features: const [
              InputFeature.leading(Icon(LucideIcons.lock)),
              InputFeature.passwordToggle(),
            ],
            onSubmitted: (_) => onSubmit(),
          ),
          if (passwordError != null) ...[
            const SizedBox(height: 6),
            _FieldError(message: passwordError!),
          ],
          if (serverError != null) ...[
            const SizedBox(height: 16),
            _AuthErrorBanner(message: serverError!),
            if (offline) ...[
              const SizedBox(height: 8),
              Button.ghost(
                onPressed: authLoading ? null : onRetry,
                leading: const Icon(LucideIcons.refreshCw),
                child: const Text('Reintentar conexión'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Button.primary(
              onPressed: authLoading ? null : onSubmit,
              leading: authLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLogin ? LucideIcons.logIn : LucideIcons.userPlus),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.12),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Image.asset('assets/logo.png', width: 44, height: 44),
        ),
        const SizedBox(height: 16),
        Text(
          'Tether',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.foreground,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: isLogin
                ? Button.secondary(
                    onPressed: () => onChanged(_AuthMode.login),
                    child: const Text('Iniciar sesión'),
                  )
                : Button.ghost(
                    onPressed: () => onChanged(_AuthMode.login),
                    child: const Text('Iniciar sesión'),
                  ),
          ),
          Expanded(
            child: isLogin
                ? Button.ghost(
                    onPressed: () => onChanged(_AuthMode.register),
                    child: const Text('Crear cuenta'),
                  )
                : Button.secondary(
                    onPressed: () => onChanged(_AuthMode.register),
                    child: const Text('Crear cuenta'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: scheme.foreground,
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 14, color: scheme.destructive),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: scheme.destructive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.destructive.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.triangleAlert, color: scheme.destructive),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.destructive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondo de constelación: nodos conectados con una "señal" que viaja entre
/// ellos. Respeta la preferencia de movimiento reducido del sistema.
class _ConstellationBackground extends StatefulWidget {
  const _ConstellationBackground();

  @override
  State<_ConstellationBackground> createState() =>
      _ConstellationBackgroundState();
}

class _ConstellationBackgroundState extends State<_ConstellationBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = _ConstellationColors(
      line: scheme.border.withValues(alpha: 0.7),
      nodeColors: [
        scheme.primary,
        scheme.secondary,
        scheme.accent,
        scheme.chart1,
      ],
      signal: scheme.accent,
    );

    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: Curves.easeOut.transform(_controller.value),
            child: CustomPaint(
              painter: _ConstellationPainter(
                t: _controller.value,
                colors: colors,
              ),
              child: child,
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ConstellationColors {
  const _ConstellationColors({
    required this.line,
    required this.nodeColors,
    required this.signal,
  });

  final Color line;
  final List<Color> nodeColors;
  final Color signal;
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({required this.t, required this.colors});

  final double t;
  final _ConstellationColors colors;

  static const _nodes = <Offset>[
    Offset(0.06, 0.20),
    Offset(0.18, 0.08),
    Offset(0.34, 0.22),
    Offset(0.52, 0.10),
    Offset(0.70, 0.24),
    Offset(0.88, 0.12),
    Offset(0.96, 0.34),
    Offset(0.10, 0.52),
    Offset(0.28, 0.42),
    Offset(0.48, 0.58),
    Offset(0.66, 0.46),
    Offset(0.84, 0.56),
    Offset(0.16, 0.78),
    Offset(0.38, 0.80),
    Offset(0.60, 0.84),
    Offset(0.86, 0.88),
    Offset(0.06, 0.94),
  ];

  static const _edges = <List<int>>[
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [4, 5],
    [5, 6],
    [7, 8],
    [8, 9],
    [9, 10],
    [10, 11],
    [12, 13],
    [13, 14],
    [14, 15],
    [0, 7],
    [2, 8],
    [3, 9],
    [4, 10],
    [5, 11],
    [8, 12],
    [9, 13],
    [10, 14],
    [11, 15],
    [12, 16],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _nodes
        .map((o) => Offset(o.dx * size.width, o.dy * size.height))
        .toList();

    final linePaint = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (final e in _edges) {
      canvas.drawLine(pts[e[0]], pts[e[1]], linePaint);
    }

    for (var i = 0; i < pts.length; i++) {
      final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (t + i * 0.13));
      final nodeColor = colors.nodeColors[i % colors.nodeColors.length]
          .withValues(alpha: 0.30 + 0.45 * pulse);
      canvas.drawCircle(
        pts[i],
        1.6 + 1.4 * pulse,
        Paint()..color = nodeColor,
      );
    }

    final segCount = _edges.length;
    final pos = t * segCount;
    final seg = pos.floor() % segCount;
    final local = pos - pos.floor();
    final a = pts[_edges[seg][0]];
    final b = pts[_edges[seg][1]];
    final signal = Offset.lerp(a, b, local)!;
    canvas.drawCircle(
      signal,
      7,
      Paint()..color = colors.signal.withValues(alpha: 0.20),
    );
    canvas.drawCircle(signal, 3, Paint()..color = colors.signal);
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colors != colors;
}
