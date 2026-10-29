import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../site_labels.dart';
import '../types.dart';

/// Mesa del plano de sala: un punto por silla alrededor del número.
class SiteFloorTable extends StatelessWidget {
  const SiteFloorTable({super.key, required this.table, required this.selected, required this.onSelect});

  final LiveTable table;
  final bool selected;
  final VoidCallback onSelect;

  static const double _size = 88;
  static const double _radius = 34;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color border, Color background, Color foreground) = switch (table.floorStatus) {
      'occupied' => (c.primary, c.primary, c.onPrimary),
      'reserved' => (c.tertiary, c.tertiaryFixed, c.onTertiaryContainer),
      'cleaning' => (c.outline, c.surfaceContainerHigh, c.onSurfaceVariant),
      _ => (c.outlineVariant, c.surfaceContainerLowest, c.onSurface),
    };
    final total = max(table.seats, 1);
    final isActive = table.status == 'active';

    return Semantics(
      button: true,
      selected: selected,
      label: 'Mesa ${table.number}, ${floorStatusLabel[table.floorStatus] ?? table.floorStatus}, '
          '${table.occupiedSeats} de ${table.seats} sillas',
      child: Material(
        color: selected ? c.surfaceContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected ? BorderSide(color: c.primaryInk, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: Stack(
                      children: [
                        for (var index = 0; index < total; index++)
                          Builder(builder: (context) {
                            final angle = (pi * 2 * index) / total - pi / 2;
                            return Positioned(
                              left: _size / 2 + cos(angle) * _radius - 5,
                              top: _size / 2 + sin(angle) * _radius - 5,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index < table.occupiedSeats ? c.primary : c.outlineVariant,
                                ),
                              ),
                            );
                          }),
                        Center(
                          child: Opacity(
                            opacity: isActive ? 1 : 0.5,
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: border, width: isActive ? 2 : 1.5),
                              ),
                              child: Text(
                                table.number,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.label(fontSize: 12, fontWeight: FontWeight.w700, color: foreground),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      (tableStatusLabel[table.status] ?? table.status).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.label(fontSize: 11, color: c.onErrorContainer, letterSpacing: 0.4),
                    ),
                  )
                else
                  Text(
                    '${table.occupiedSeats}/${table.seats} SILLAS',
                    maxLines: 1,
                    style: AppFonts.label(fontSize: 11, color: c.onSurfaceVariant, letterSpacing: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
