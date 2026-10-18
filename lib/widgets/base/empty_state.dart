import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 'inbox' | 'check' | 'search' | 'fire' | 'receipt'
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = 'inbox', this.child});

  final String title;
  final String? message;
  final String icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconData = switch (icon) {
      'check' => Icons.check_circle_outline_rounded,
      'search' => Icons.search_rounded,
      'fire' => Icons.local_fire_department_outlined,
      'receipt' => Icons.receipt_long_outlined,
      _ => Icons.inbox_outlined,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(16)),
            child: Icon(iconData, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          ],
          if (child != null) ...[const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}
