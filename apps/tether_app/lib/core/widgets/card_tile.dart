import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Fila de lista estilo tarjeta (reemplazo shadcn de `ListTile`).
///
/// Renderiza `leading` · (título + subtítulo) · `trailing` con hover y tap.
/// Sustituye a `ListTile` en dispositivos, portapapeles, archivos y compartidos.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hover =
        Color.alphaBlend(scheme.muted.withValues(alpha: 0.5), scheme.card);

    return Clickable(
      onPressed: onTap,
      decoration: WidgetStateProperty.resolveWith((states) {
        final color =
            states.contains(WidgetState.hovered) ? hover : scheme.card;
        return BoxDecoration(
          color: color,
          border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(theme.radiusLg),
        );
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}
