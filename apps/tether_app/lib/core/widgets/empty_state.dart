import 'package:flutter/material.dart';

/// Estado vacío reutilizable (tema Material).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: colors.outline),
          const SizedBox(height: 16),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style:
                textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
