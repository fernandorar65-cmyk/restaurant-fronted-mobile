import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../site_labels.dart';
import '../types.dart';

/// Resumen de una mesa: número, sillas, etiqueta, zona y estado del servicio.
class SiteTableCard extends StatelessWidget {
  const SiteTableCard({super.key, required this.table, this.highlight = false});

  final LiveTable table;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color tagBackground, Color tagForeground) = switch (table.tagTone) {
      'critical' => (c.tertiaryContainer.withValues(alpha: 0.3), c.onTertiaryContainer),
      'alert' => (c.errorContainer, c.onErrorContainer),
      _ => (c.surfaceContainerHighest, c.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlight ? c.primary : c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  table.number,
                  maxLines: 1,
                  style: AppFonts.headline(fontSize: 15, fontWeight: FontWeight.w700, color: highlight ? c.onPrimary : c.onSurface),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Mesa ${table.number} · ${table.occupiedSeats}/${table.seats} sillas',
                          style: AppFonts.label(fontSize: 14, fontWeight: FontWeight.w700, color: c.onSurface),
                        ),
                        if (table.tagLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: tagBackground, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              table.tagLabel.toUpperCase(),
                              style: AppFonts.label(fontSize: 11, fontWeight: FontWeight.w700, color: tagForeground, letterSpacing: 0.8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${table.location} · ${table.staff} · ${floorStatusLabel[table.floorStatus] ?? table.floorStatus}',
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (highlight) ...[
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                  ],
                  Text(table.statusLabel, style: AppFonts.label(fontSize: 12, color: c.onSurface)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(table.courseLabel.toUpperCase(), style: AppFonts.label(fontSize: 11, color: c.tertiary, letterSpacing: 0.8)),
              Text(table.dish, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurface)),
              if (table.note.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                  child: Text(table.note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
