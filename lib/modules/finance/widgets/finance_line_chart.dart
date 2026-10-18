import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'finance_formats.dart';

class LineSeries {
  const LineSeries({required this.id, required this.label, required this.color, required this.values});

  final String id;
  final String label;
  final Color color;

  /// null = sin dato (por ejemplo, días que aún no llegan): la línea se corta ahí.
  final List<double?> values;
}

const double _height = 260;
const double _leftReserved = 60;

/// Evolución temporal de una o varias series (equivale a FinanceLineChart.vue).
/// Tocar o arrastrar sobre el gráfico muestra los valores de todas las series en ese punto.
class FinanceLineChart extends StatefulWidget {
  const FinanceLineChart({
    super.key,
    required this.labels,
    required this.series,
    required this.format,
    required this.formatAxis,
    required this.description,
    this.partialIndex,
  });

  final List<String> labels;
  final List<LineSeries> series;

  /// Formato completo (tooltip).
  final String Function(num value) format;

  /// Formato corto (eje Y).
  final String Function(num value) formatAxis;

  /// Texto accesible del gráfico.
  final String description;

  /// Punto incompleto (período en curso): se dibuja con un marcador hueco.
  final int? partialIndex;

  @override
  State<FinanceLineChart> createState() => _FinanceLineChartState();
}

class _FinanceLineChartState extends State<FinanceLineChart> {
  int? _activeIndex;

  @override
  void didUpdateWidget(covariant FinanceLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) _activeIndex = null;
  }

  /// Escala Y con valores redondos que incluye el cero.
  ({double lo, double hi, double step}) get _yScale {
    final all = widget.series.expand((serie) => serie.values).whereType<double>().toList();
    final minValue = all.fold<double>(0, math.min);
    final maxValue = all.fold<double>(0, math.max);
    final span = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;
    final rawStep = span / 4;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final step = [1, 2, 2.5, 5, 10].map((m) => m * magnitude).firstWhere((candidate) => candidate >= rawStep, orElse: () => magnitude * 10);
    final lo = (minValue / step).floor() * step;
    final hi = (maxValue / step).ceil() * step;
    return (lo: lo, hi: hi == lo ? lo + step : hi, step: step);
  }

  /// Último índice con dato: ahí va el punto final de cada serie.
  int get _lastIndex {
    var last = -1;
    for (final serie in widget.series) {
      for (var index = 0; index < serie.values.length; index++) {
        if (serie.values[index] != null && index > last) last = index;
      }
    }
    return last;
  }

  void _onTouch(FlTouchEvent event, double plotWidth) {
    final position = event.localPosition;
    final count = widget.labels.length;

    if (position == null || count == 0) return;

    final relative = (position.dx - _leftReserved).clamp(0, plotWidth);
    final index = count <= 1 ? 0 : ((relative / plotWidth) * (count - 1)).round();
    final next = index.clamp(0, count - 1);

    if (event is FlTapUpEvent && _activeIndex == next) {
      // Tocar de nuevo el mismo punto oculta el detalle.
      setState(() => _activeIndex = null);
      return;
    }

    if (event is FlTapDownEvent || event is FlPanStartEvent || event is FlPanUpdateEvent || event is FlLongPressMoveUpdate) {
      if (_activeIndex != next) setState(() => _activeIndex = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = _yScale;
    final count = widget.labels.length;
    final lastIndex = _lastIndex;
    final active = _activeIndex;
    final axisStyle = TextStyle(fontSize: 11, color: c.outline, fontFeatures: tabularFigures);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Leyenda: siempre con 2 o más series.
        if (widget.series.length > 1) ...[
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final serie in widget.series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 16, height: 3, decoration: BoxDecoration(color: serie.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(serie.label, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _Tooltip(
          label: active == null ? null : widget.labels[active],
          rows: active == null
              ? const []
              : (widget.series
                    .where((serie) => active < serie.values.length && serie.values[active] != null)
                    .map((serie) => (serie: serie, value: serie.values[active]!))
                    .toList()
                  ..sort((a, b) => b.value.compareTo(a.value))),
          format: widget.format,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: widget.description,
          child: SizedBox(
            height: _height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final plotWidth = math.max(1.0, constraints.maxWidth - _leftReserved - 8);
                final every = math.max(1, (count / math.max(2, (plotWidth / 70).floor())).ceil());

                return LineChart(
                  duration: const Duration(milliseconds: 150),
                  LineChartData(
                    minX: 0,
                    maxX: math.max(1, count - 1).toDouble(),
                    minY: scale.lo,
                    maxY: scale.hi,
                    clipData: const FlClipData.none(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: scale.step,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: value.abs() < scale.step / 1000 ? c.outlineVariant : c.outlineVariant.withValues(alpha: 0.4),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 8, getTitlesWidget: _empty)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: _leftReserved,
                          interval: scale.step,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(widget.formatAxis(value), style: axisStyle),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            final isTick = index == value &&
                                index >= 0 &&
                                index < count &&
                                (index % every == 0 || (index == count - 1 && index % every >= every / 2));

                            if (!isTick) return const SizedBox.shrink();

                            return SideTitleWidget(
                              meta: meta,
                              child: Text(widget.labels[index].replaceAll(' (en curso)', '*'), style: axisStyle),
                            );
                          },
                        ),
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      verticalLines: [if (active != null) VerticalLine(x: active.toDouble(), color: c.outline, strokeWidth: 1)],
                    ),
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: false,
                      touchCallback: (event, _) => _onTouch(event, plotWidth),
                    ),
                    lineBarsData: [
                      for (final serie in widget.series)
                        LineChartBarData(
                          spots: [
                            for (var index = 0; index < serie.values.length; index++)
                              serie.values[index] == null ? FlSpot.nullSpot : FlSpot(index.toDouble(), serie.values[index]!),
                          ],
                          color: serie.color,
                          barWidth: 2,
                          isCurved: false,
                          isStrokeCapRound: true,
                          isStrokeJoinRound: true,
                          belowBarData: BarAreaData(show: false),
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, _) {
                              final index = spot.x.round();
                              return index == lastIndex || index == active || index == widget.partialIndex;
                            },
                            getDotPainter: (spot, _, _, _) {
                              final index = spot.x.round();

                              // Punto del período en curso: hueco, para leerlo como dato parcial.
                              if (index == widget.partialIndex && index != active) {
                                return FlDotCirclePainter(radius: 4, color: c.surfaceContainerLowest, strokeWidth: 2, strokeColor: serie.color);
                              }

                              return FlDotCirclePainter(
                                radius: index == active ? 5 : 4,
                                color: serie.color,
                                strokeWidth: 2,
                                strokeColor: c.surfaceContainerLowest,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

Widget _empty(double value, TitleMeta meta) => const SizedBox.shrink();

/// Detalle del punto tocado: valores de todas las series, de mayor a menor.
class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.label, required this.rows, required this.format});

  final String? label;
  final List<({LineSeries serie, double value})> rows;
  final String Function(num value) format;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (label == null) {
      return Text('Toca el gráfico para ver los valores de cada punto.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant));
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label!, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            const SizedBox(height: 2),
            if (rows.isEmpty) Text('Sin datos todavía', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(width: 12, height: 3, decoration: BoxDecoration(color: row.serie.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text(
                      format(row.value),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface, fontFeatures: tabularFigures),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(row.serie.label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
