import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Diálogo con cuerpo shadcn (`Card`) para mostrarse con `showDialog` de
/// Material, consistente con el resto del design system.
///
/// Úsalo pasando las acciones como botones shadcn que llaman a
/// `Navigator.pop(context, valor)`.
class TetherDialog extends StatelessWidget {
  const TetherDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              child: title,
            ),
            const SizedBox(height: 10),
            content,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
