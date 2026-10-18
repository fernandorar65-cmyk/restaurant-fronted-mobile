import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.label, required this.value, this.hint, this.tone = 'default', this.child});

  final String label;
  final String value;
  final String? hint;

  /// 'default' | 'danger' | 'success' | 'warning'
  final String tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final valueColor = switch (tone) {
      'danger' => c.error,
      'success' => c.success,
      'warning' => c.warning,
      _ => c.onSurface,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.headline(fontSize: 26, color: valueColor).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
          ],
          ?child,
        ],
      ),
    );
  }
}
