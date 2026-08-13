import 'package:flutter/material.dart';

/// Etiqueta de estado reutilizable (tema Material) con fondo tonal.
///
/// Admite un icono (`icon`), un punto indicador (`dot`) o ambos, y un
/// `tooltip` opcional para accesibilidad.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.foreground,
    this.icon,
    this.dot = false,
    this.tooltip,
  });

  final String label;
  final Color color;
  final Color foreground;
  final IconData? icon;
  final bool dot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
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

    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}
