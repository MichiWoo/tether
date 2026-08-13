import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dracula_palette.dart';
import '../../../core/widgets/card_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/tether_dialog.dart';
import '../domain/device.dart';
import '../providers/devices_provider.dart';

/// Pantalla de dispositivos del usuario: lista con estado online/offline,
/// registro, renombrado y eliminación.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(devicesControllerProvider.notifier).load());
  }

  Future<void> _register() async {
    final name = await _promptText(
      title: 'Registrar dispositivo',
      label: 'Nombre',
      hint: 'Ej. MacBook Pro',
    );
    if (name == null || !mounted) return;
    await ref.read(devicesControllerProvider.notifier).register(
          name: name,
          platform: currentPlatform(),
        );
  }

  Future<void> _rename(Device device) async {
    final name = await _promptText(
      title: 'Renombrar dispositivo',
      label: 'Nombre',
      initial: device.name,
    );
    if (name == null || !mounted) return;
    await ref.read(devicesControllerProvider.notifier).rename(device.id, name);
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String? hint,
    String? initial,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(
        title: title,
        label: label,
        hint: hint,
        initial: initial,
      ),
    );
    return result == null || result.isEmpty ? null : result;
  }

  Future<void> _confirmDelete(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => TetherDialog(
        title: const Text('Eliminar dispositivo'),
        content: Text(
          '¿Eliminar "${device.name}"? Se desvinculará de tu cuenta.',
        ),
        actions: [
          shadcn.Button.ghost(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          shadcn.Button.destructive(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(devicesControllerProvider.notifier).delete(device.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devicesControllerProvider);
    final localId = ref.watch(localDeviceIdProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Text(
                '${state.devices.length} dispositivo(s)',
                style: AppFonts.monoStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              shadcn.Button.primary(
                onPressed: _register,
                leading: const Icon(Icons.add),
                child: const Text('Registrar'),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ErrorBanner(message: state.error!),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (state.devices.isEmpty) {
            true => const EmptyState(
                icon: Icons.devices_other_outlined,
                title: 'Sin dispositivos',
                subtitle: 'Registra tu primer dispositivo para empezar.',
              ),
            false => RefreshIndicator(
                onRefresh: () async =>
                    ref.read(devicesControllerProvider.notifier).load(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  itemCount: state.devices.length,
                  itemBuilder: (context, index) {
                    final device = state.devices[index];
                    final isCurrent = device.id == localId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DeviceTile(
                        device: device,
                        isCurrent: isCurrent,
                        onRename: () => _rename(device),
                        onDelete: () => _confirmDelete(device),
                      ),
                    );
                  },
                ),
              ),
          },
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    this.hint,
    this.initial,
  });

  final String title;
  final String label;
  final String? hint;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return TetherDialog(
      title: Text(widget.title),
      content: shadcn.TextField(
        key: const Key('name-input'),
        controller: _controller,
        autofocus: true,
        hintText: widget.hint ?? widget.label,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        shadcn.Button.ghost(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        shadcn.Button.primary(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isCurrent,
    required this.onRename,
    required this.onDelete,
  });

  final Device device;
  final bool isCurrent;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CardTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _iconFor(device.platform),
          color: colors.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              device.name,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            StatusChip(
              label: 'Este equipo',
              color: colors.primaryContainer,
              foreground: colors.onPrimaryContainer,
            ),
          ],
        ],
      ),
      subtitle: Text(
        device.platform.label,
        style: AppFonts.monoStyle(
          fontSize: 12,
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBadge(online: device.isOnline),
          const SizedBox(width: 8),
          Builder(
            builder: (context) => shadcn.IconButton.ghost(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _openMenu(context),
            ),
          ),
        ],
      ),
      onTap: onRename,
    );
  }

  void _openMenu(BuildContext context) {
    shadcn.showDropdown<void>(
      context: context,
      follow: false,
      builder: (_) => shadcn.DropdownMenu(
        children: [
          shadcn.MenuButton(
            leading: const Icon(Icons.edit_outlined),
            child: const Text('Renombrar'),
            onPressed: (_) => onRename(),
          ),
          shadcn.MenuButton(
            leading: const Icon(Icons.delete_outline),
            child: const Text('Eliminar'),
            onPressed: (_) => onDelete(),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(DevicePlatform platform) => switch (platform) {
        DevicePlatform.macos => Icons.laptop_mac,
        DevicePlatform.windows => Icons.laptop_windows,
        DevicePlatform.linux => Icons.laptop,
        DevicePlatform.ios => Icons.phone_iphone,
        DevicePlatform.android => Icons.phone_android,
        DevicePlatform.web => Icons.language,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: online ? 'En línea' : 'Desconectado',
      color: online
          ? StatusColors.success(context).withValues(alpha: 0.15)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      foreground: online
          ? StatusColors.success(context)
          : Theme.of(context).colorScheme.onSurfaceVariant,
      icon: online ? Icons.circle : Icons.circle_outlined,
    );
  }
}
