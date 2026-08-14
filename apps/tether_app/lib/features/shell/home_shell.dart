import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../core/realtime/realtime_provider.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/platform/platform_info.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/dracula_palette.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/status_chip.dart';
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
    if (isMobile) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: _buildContent(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _section.index,
          onDestinationSelected: (index) {
            setState(() => _section = _Section.values[index]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other),
              label: 'Dispositivos',
            ),
            NavigationDestination(
              icon: Icon(Icons.content_paste_go_outlined),
              selectedIcon: Icon(Icons.content_paste_go),
              label: 'Portapapeles',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy),
              label: 'Archivos',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _section.index,
            onSelected: (index) {
              setState(() => _section = _Section.values[index]);
            },
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildContent()),
        ],
      ),
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

/// Barra lateral con la marca, el estado realtime y la navegación.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (
      icon: Icons.devices_other_outlined,
      selectedIcon: Icons.devices_other,
      label: 'Dispositivos'
    ),
    (
      icon: Icons.content_paste_go_outlined,
      selectedIcon: Icons.content_paste_go,
      label: 'Portapapeles'
    ),
    (
      icon: Icons.folder_copy_outlined,
      selectedIcon: Icons.folder_copy,
      label: 'Archivos'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtime = ref.watch(realtimeServiceProvider);
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 208,
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Image.asset('assets/logo.png'),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tether',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RealtimeBadge(status: realtime.status),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++)
            _NavItem(
              icon: _items[i].icon,
              selectedIcon: _items[i].selectedIcon,
              label: _items[i].label,
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = selected ? colors.primaryContainer : Colors.transparent;
    final foreground =
        selected ? colors.onPrimaryContainer : colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon,
                    size: 18, color: foreground),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
            ).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
          const Spacer(),
          shadcn.IconButton.ghost(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (context) => shadcn.IconButton.ghost(
              icon: const Icon(Icons.account_circle),
              onPressed: () => shadcn.showDropdown<void>(
                context: context,
                follow: false,
                builder: (_) => shadcn.DropdownMenu(
                  children: [
                    shadcn.MenuLabel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                    const shadcn.MenuDivider(),
                    shadcn.MenuButton(
                      leading: const Icon(Icons.logout),
                      child: const Text('Cerrar sesión'),
                      onPressed: (_) =>
                          ref.read(authControllerProvider.notifier).logout(),
                    ),
                  ],
                ),
              ),
            ),
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
      RealtimeStatus.connected => (StatusColors.success(context), 'En línea'),
      RealtimeStatus.connecting => (
          StatusColors.warning(context),
          'Conectando…'
        ),
      RealtimeStatus.disconnected => (
          StatusColors.danger(context),
          'Sin conexión'
        ),
    };

    return StatusChip(
      label: label,
      color: color.withValues(alpha: 0.15),
      foreground: color,
      dot: true,
      tooltip: 'Realtime: $label',
    );
  }
}
