import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_provider.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../auth/domain/models.dart';
import '../auth/providers/auth_provider.dart';
import '../clipboard/presentation/clipboard_screen.dart';
import '../devices/presentation/devices_screen.dart';
import '../files/presentation/files_screen.dart';

enum _Section { devices, clipboard, files }

/// Vista principal de la app de escritorio.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.user});

  final User user;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  _Section _section = _Section.clipboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildRail(),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildRail() {
    final realtime = ref.watch(realtimeServiceProvider);
    return NavigationRail(
      selectedIndex: _section.index,
      onDestinationSelected: (index) {
        setState(() => _section = _Section.values[index]);
      },
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _RealtimeBadge(status: realtime.status),
            const SizedBox(height: 8),
            const Icon(Icons.link, size: 28),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.devices_other_outlined),
          selectedIcon: Icon(Icons.devices_other),
          label: Text('Dispositivos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.content_paste_go_outlined),
          selectedIcon: Icon(Icons.content_paste_go),
          label: Text('Portapapeles'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.folder_copy_outlined),
          selectedIcon: Icon(Icons.folder_copy),
          label: Text('Archivos'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _TopBar(user: widget.user, title: _section.title),
        const Divider(height: 1),
        Expanded(child: _buildSection()),
      ],
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _Section.devices:
        return const DevicesScreen();
      case _Section.clipboard:
        return const ClipboardScreen();
      case _Section.files:
        return const FilesScreen();
    }
  }
}

extension on _Section {
  String get title => switch (this) {
    _Section.devices => 'Dispositivos',
    _Section.clipboard => 'Portapapeles',
    _Section.files => 'Archivos',
  };
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.user, required this.title});

  final User user;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            tooltip: themeMode == ThemeMode.dark ? 'Modo claro' : 'Modo oscuro',
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 8),
          MenuAnchor(
            builder: (context, controller, _) => IconButton(
              tooltip: user.email,
              icon: const Icon(Icons.account_circle),
              onPressed: () => controller.isOpen
                  ? controller.close()
                  : controller.open(),
            ),
            menuChildren: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.logout),
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .logout(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RealtimeBadge extends StatelessWidget {
  const _RealtimeBadge({required this.status});

  final RealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      RealtimeStatus.connected => (Colors.green, 'En línea'),
      RealtimeStatus.connecting => (Colors.amber, 'Conectando…'),
      RealtimeStatus.disconnected => (Colors.redAccent, 'Sin conexión'),
    };

    return Tooltip(
      message: 'Realtime: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
