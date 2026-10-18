import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'finance_formats.dart';

class BarItem {
  const BarItem({required this.id, required this.label, required this.color, required this.value, required this.details});

  final String id;
  final String label;
  final Color color;
  final double value;

  /// Líneas extra del detalle (p. ej. ingresos y costos).
  final List<({String label, String value})> details;
}

/// Barras horizontales por local, con el valor al final de cada barra (equivale a FinanceBarChart.vue).
/// Admite negativos: la barra crece a la izquierda del cero. Tocar un local lo abre;
/// mantenerlo presionado muestra su detalle.
class FinanceBarChart extends StatefulWidget {
  const FinanceBarChart({super.key, required this.items, required this.format, required this.onSelect});

  final List<BarItem> items;
  final String Function(num value) format;
  final ValueChanged<String> onSelect;

  @override
  State<FinanceBarChart> createState() => _FinanceBarChartState();
}

class _FinanceBarChartState extends State<FinanceBarChart> {
  String? _active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = widget.items.map((item) => item.value);
    // Escala con margen extra para que el valor quepa fuera del extremo de la barra más larga.
    final minValue = values.fold<double>(0, math.min) * 1.35;
    final maxValue = values.fold<double>(0, math.max) * 1.35;
    final span = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;
    final zero = -minValue / span;

    return Column(
      children: [
        for (final item in widget.items)
          Material(
            color: _active == item.id ? c.surfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onSelect(item.id),
              onLongPress: () => setState(() => _active = _active == item.id ? null : item.id),
              child: Semantics(
                button: true,
                label: '${item.label}: ${widget.format(item.value)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 108,
                            child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.onSurface)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 24,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final size = item.value.abs() / span * width;
                                  final zeroX = zero * width;
                                  final barLeft = item.value >= 0 ? zeroX : zeroX - size;
                                  final labelLeft = item.value >= 0 ? math.min(zeroX + size, width) + 6 : zeroX + 6;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(left: zeroX, top: 0, bottom: 0, child: Container(width: 1, color: c.outlineVariant)),
                                      Positioned(
                                        left: barLeft,
                                        top: 2,
                                        bottom: 2,
                                        width: size,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: item.color,
                                            borderRadius: item.value >= 0
                                                ? const BorderRadius.horizontal(right: Radius.circular(4))
                                                : const BorderRadius.horizontal(left: Radius.circular(4)),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: labelLeft,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: Text(
                                            widget.format(item.value),
                                            softWrap: false,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: c.onSurface,
                                              fontFeatures: tabularFigures,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_active == item.id)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item.label, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
                                ],
                              ),
                              for (final detail in item.details)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(detail.label, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                                      Text(
                                        detail.value,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: c.onSurface,
                                          fontFeatures: tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
