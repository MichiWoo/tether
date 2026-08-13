import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      builder: (context) => AlertDialog(
        title: const Text('Eliminar dispositivo'),
        content: Text(
          '¿Eliminar "${device.name}"? Se desvinculará de tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _register,
                icon: const Icon(Icons.add),
                label: const Text('Registrar'),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ErrorBanner(message: state.error!),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (state.devices.isEmpty) {
            true => const _EmptyState(),
            false => RefreshIndicator(
                onRefresh: () async =>
                    ref.read(devicesControllerProvider.notifier).load(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: state.devices.length,
                  itemBuilder: (context, index) {
                    final device = state.devices[index];
                    final isCurrent = device.id == localId;
                    return _DeviceTile(
                      device: device,
                      isCurrent: isCurrent,
                      onRename: () => _rename(device),
                      onDelete: () => _confirmDelete(device),
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
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
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

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.surfaceContainerHighest,
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
            _Chip(
              label: 'Este equipo',
              color: colors.primaryContainer,
              foreground: colors.onPrimaryContainer,
            ),
          ],
        ],
      ),
      subtitle: Text(
        device.platform.label,
        style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBadge(online: device.isOnline),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  onRename();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
      onTap: onRename,
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
    return _Chip(
      label: online ? 'En línea' : 'Desconectado',
      color: online
          ? Colors.green.withOpacity(0.15)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      foreground: online
          ? const Color(0xFF1B5E20)
          : Theme.of(context).colorScheme.onSurfaceVariant,
      icon: online ? Icons.circle : Icons.circle_outlined,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color color;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other_outlined, size: 48, color: colors.outline),
          const SizedBox(height: 16),
          Text('Sin dispositivos', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Registra tu primer dispositivo para empezar.',
            style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
