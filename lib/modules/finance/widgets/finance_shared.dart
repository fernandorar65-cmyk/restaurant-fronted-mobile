import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../finance_period.dart';
import '../period.dart';
import '../types.dart';
import 'finance_formats.dart';

/// Cálculos y piezas comunes al resumen de Finanzas y al detalle de un local.

/// Tramo con el que se compara. Si el período está en curso, se compara el mismo
/// número de días del período anterior (1–11 oct vs. 1–11 sep), no el período completo.
PeriodRange previousRangeFor(FinancePeriodKind period, String anchor, String today) {
  final current = periodRange(period, anchor);
  final full = periodRange(period, previousAnchor(period, anchor));

  if (current.to.compareTo(today) <= 0) {
    return full;
  }

  final elapsedDays = (parseDateKey(today).difference(parseDateKey(current.from)).inHours / 24).round();
  final start = parseDateKey(full.from);
  final to = toDateKey(DateTime(start.year, start.month, start.day + elapsedDays));
  return PeriodRange(from: full.from, to: to.compareTo(full.to) < 0 ? to : full.to);
}

/// Texto de la comparación según el período (y si está en curso).
String comparisonTextFor(FinancePeriodKind period, String anchor, String today) {
  final isPartial = periodRange(period, anchor).to.compareTo(today) > 0;
  if (!isPartial) return comparisonLabel(period);
  return period == 'month' ? 'vs. mismos días del mes anterior' : 'vs. mismo tramo del año anterior';
}

/// Un solo pedido cubre el período, su comparación y la evolución.
PeriodRange fetchRangeFor(FinancePeriodKind period, String anchor, String today) {
  final ranges = [
    periodRange(period, anchor),
    previousRangeFor(period, anchor, today),
    for (final bucket in timeBuckets(period, anchor)) PeriodRange(from: bucket.from, to: bucket.to),
  ];
  final froms = ranges.map((range) => range.from).toList()..sort();
  final tos = ranges.map((range) => range.to).toList()..sort();
  return PeriodRange(from: froms.first, to: tos.last);
}

List<DailyFinancial> rowsInRange(List<DailyFinancial> rows, String from, String to, bool Function(String restaurantId) includes) =>
    rows.where((row) => includes(row.restaurantId) && row.date.compareTo(from) >= 0 && row.date.compareTo(to) <= 0).toList();

/// Solo se compara si el período anterior tiene datos de una cantidad parecida de días.
bool isComparable(List<DailyFinancial> current, List<DailyFinancial> previous) {
  int days(List<DailyFinancial> list) => list.map((row) => row.date).toSet().length;
  final count = days(current);
  return count > 0 && days(previous) >= count * 0.8;
}

double ticketOf(FinanceTotals value) => value.orders > 0 ? value.revenue / value.orders : 0;

double marginOf(FinanceTotals value) => value.revenue > 0 ? value.profit / value.revenue : 0;

const Map<FinancePeriodKind, String> evolutionTitles = {'day': 'Últimos 14 días', 'month': 'Día a día', 'year': 'Mes a mes'};

/// Bucket del mes en curso en la vista anual (incompleto), o null.
String? partialBucketKey(FinancePeriodKind period, List<TimeBucket> buckets, String today) {
  if (period != 'year') return null;
  return buckets.where((bucket) => bucket.from.compareTo(today) <= 0 && bucket.to.compareTo(today) > 0).firstOrNull?.key;
}

/// Período y fecha leídos de la URL (?periodo=mes&fecha=…) y escritos de vuelta al cambiar,
/// para conservarlos al pasar del resumen al detalle de un local y al volver.
mixin FinancePeriodQuery<T extends StatefulWidget> on State<T> {
  FinancePeriod? _financePeriod;

  FinancePeriod get financePeriod => _financePeriod!;

  /// Se llama cuando cambia el período o la fecha.
  void onPeriodChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_financePeriod == null) {
      final query = GoRouterState.of(context).uri.queryParameters;
      _financePeriod = FinancePeriod(periodo: query['periodo'], fecha: query['fecha'])..addListener(_handleChange);
    }
  }

  void _handleChange() {
    final uri = GoRouter.of(context).state.uri;
    context.go(uri.replace(queryParameters: {...uri.queryParameters, ...financePeriod.periodQuery()}).toString());
    onPeriodChanged();
  }

  @override
  void dispose() {
    _financePeriod?.removeListener(_handleChange);
    _financePeriod?.dispose();
    super.dispose();
  }
}

/// Tarjeta de indicador con variación frente al período anterior.
class FinanceTile extends StatelessWidget {
  const FinanceTile({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.delta,
    required this.comparisonText,
    this.upIsGood = true,
  });

  final String label;
  final String value;
  final String hint;
  final double? delta;
  final String comparisonText;

  /// En gastos, subir es malo: el color de la variación se invierte.
  final bool upIsGood;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delta = this.delta;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.body(fontSize: 22, fontWeight: FontWeight.w600, color: c.onSurface).copyWith(fontFeatures: tabularFigures),
            ),
          ),
          const SizedBox(height: 2),
          if (delta != null)
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DeltaText(delta: delta, upIsGood: upIsGood),
                Text(comparisonText, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
              ],
            )
          else
            Text(hint, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// "▲ +12,5 %" en verde o rojo según si la variación es buena.
class DeltaText extends StatelessWidget {
  const DeltaText({super.key, required this.delta, this.upIsGood = true, this.showIcon = true});

  final double delta;
  final bool upIsGood;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final good = (delta >= 0) == upIsGood;
    final color = good ? c.success : c.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) Icon(delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: color),
        Text(
          FinanceFormats.delta(delta),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFeatures: tabularFigures),
        ),
      ],
    );
  }
}

/// Sección con fondo, título y descripción.
class FinanceSection extends StatelessWidget {
  const FinanceSection({super.key, required this.title, this.description, this.trailing, required this.children});

  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(description!, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
          ],
          if (trailing != null) ...[const SizedBox(height: 10), trailing!],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Par etiqueta / valor en las tarjetas de detalle.
class FigureCell extends StatelessWidget {
  const FigureCell({super.key, required this.label, required this.value, this.color, this.bold = false});

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            color: color ?? c.onSurface,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// Rejilla de cifras en filas de [columns].
class FigureGrid extends StatelessWidget {
  const FigureGrid({super.key, required this.cells, this.columns = 3});

  final List<Widget> cells;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var index = 0; index < cells.length; index += columns) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var offset = 0; offset < columns; offset++)
                Expanded(child: index + offset < cells.length ? cells[index + offset] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Aviso de período sin ventas.
class NoSalesNotice extends StatelessWidget {
  const NoSalesNotice({super.key, required this.period});

  final FinancePeriodKind period;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Text(
        'No hay ventas registradas en este período${period == 'day' ? ' (el local pudo estar cerrado)' : ''}.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
      ),
    );
  }
}
