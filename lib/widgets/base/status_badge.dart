import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 'neutral' | 'info' | 'progress' | 'success' | 'warning' | 'danger' | 'muted'
typedef StatusTone = String;

/// Cada tono lleva su ícono: el estado nunca depende solo del color.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.tone, required this.label, this.size = 'sm'});

  final StatusTone tone;
  final String label;
  final String size;

  static IconData iconFor(StatusTone tone) => switch (tone) {
        'info' => Icons.check_rounded,
        'progress' => Icons.autorenew_rounded,
        'success' => Icons.check_circle_outline_rounded,
        'warning' => Icons.warning_amber_rounded,
        'danger' => Icons.cancel_outlined,
        'muted' => Icons.block_rounded,
        _ => Icons.schedule_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color background, Color foreground) = switch (tone) {
      'info' => (c.primaryFixed, c.onPrimaryFixed),
      'progress' => (c.primary, c.onPrimary),
      'success' => (c.successContainer, c.onSuccessContainer),
      'warning' => (c.warningContainer, c.onWarningContainer),
      'danger' => (c.errorContainer, c.onErrorContainer),
      'muted' => (c.surfaceContainerHigh, c.onSurfaceVariant),
      _ => (c.secondaryContainer, c.onSurface),
    };
    final isMd = size == 'md';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMd ? 12 : 8, vertical: isMd ? 4 : 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(tone), size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: AppFonts.label(fontSize: isMd ? 13 : 12, color: foreground)),
        ],
      ),
    );
  }
}
