import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../metrics.dart';

/// Ranking en barras horizontales de un solo tono (equivale a RankedBars.vue).
class RankedBars extends StatelessWidget {
  const RankedBars({super.key, required this.items, this.unit, this.format, this.emptyLabel});

  final List<RankedItem> items;

  /// Unidad que acompaña al valor en la etiqueta (ej: "uds").
  final String? unit;
  final String Function(num value)? format;
  final String? emptyLabel;

  String _label(num value) {
    if (format != null) return format!(value);
    final text = value == value.roundToDouble() ? '${value.round()}' : '$value';
    return unit != null ? '$text $unit' : text;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (items.isEmpty) {
      return Text(emptyLabel ?? 'Sin datos en este período.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant));
    }

    final maxValue = items.fold<num>(1, (value, item) => math.max(value, item.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Semantics(
            label: item.detail != null ? '${item.label}: ${_label(item.value)} — ${item.detail}' : '${item.label}: ${_label(item.value)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.onSurface)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _label(item.value),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (item.value / maxValue).clamp(0, 1).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(999), right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  if (item.detail != null && item.detail!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
