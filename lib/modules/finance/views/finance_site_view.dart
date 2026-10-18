import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../administration/widgets/admin_form.dart';
import '../../payments/api.dart' show paymentMethodLabel;
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../period.dart';
import '../types.dart';
import '../widgets/finance_formats.dart';
import '../widgets/finance_line_chart.dart';
import '../widgets/finance_period_picker.dart';
import '../widgets/finance_shared.dart';
import 'finance_view.dart' show compareSiteIds;

const List<({String key, String label, String hint})> _expenseCategories = [
  (key: 'food', label: 'Insumos', hint: 'Alimentos y bebidas'),
  (key: 'labor', label: 'Personal', hint: 'Sueldos y cargas'),
  (key: 'rent', label: 'Alquiler', hint: 'Local'),
  (key: 'utilities', label: 'Servicios', hint: 'Luz, agua, gas, internet'),
  (key: 'maintenance', label: 'Mantenimiento', hint: 'Equipos y reparaciones'),
  (key: 'marketing', label: 'Marketing', hint: 'Publicidad y promociones'),
  (key: 'other', label: 'Otros', hint: 'Gastos varios'),
];

const List<String> _methodOrder = ['card', 'yape', 'plin', 'transfer', 'cash'];

double _expenseValue(FinanceTotals value, String key) => switch (key) {
      'food' => value.foodCost,
      'labor' => value.laborCost,
      _ => value.expenses[key],
    };

/// Detalle de ingresos y gastos de un local (equivale a FinanceSiteView.vue).
class FinanceSiteView extends StatefulWidget {
  const FinanceSiteView({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<FinanceSiteView> createState() => _FinanceSiteViewState();
}

class _FinanceSiteViewState extends State<FinanceSiteView> with FinancePeriodQuery<FinanceSiteView> {
  List<RestaurantSite> _restaurants = [];
  List<DailyFinancial> _rows = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _loadError = false;
  String? _loadedRangeKey;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _init();
    }
  }

  Future<void> _init() async {
    try {
      _restaurants = await fetchRestaurants();
    } catch (_) {
      _loadError = true;
    }

    if (mounted) await _load();
  }

  String get _today => financePeriod.today;

  @override
  void onPeriodChanged() {
    setState(() {});
    final range = fetchRangeFor(financePeriod.period, financePeriod.anchor, _today);
    if ('${range.from}|${range.to}' != _loadedRangeKey) _load();
  }

  Future<void> _load() async {
    final range = fetchRangeFor(financePeriod.period, financePeriod.anchor, _today);
    final first = _rows.isEmpty;
    final key = '${range.from}|${range.to}';
    _loadedRangeKey = key;
    setState(() {
      _isLoading = first;
      _isRefreshing = !first;
      _loadError = false;
    });

    try {
      final rows = await fetchDailyFinancials(range.from, range.to);
      if (key == _loadedRangeKey) _rows = rows;
    } catch (_) {
      _loadError = true;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _changeSite(String next) {
    context.go(Uri(path: Routes.financeSite(next), queryParameters: financePeriod.periodQuery()).toString());
  }

  String _dateLabel(String key) {
    if (financePeriod.period == 'year') {
      return capitalizeFirst(DateFormat('MMMM', 'es').format(parseDateKey('$key-01')));
    }

    return capitalizeFirst(DateFormat('EEE, d MMM', 'es').format(parseDateKey(key)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final period = financePeriod.period;
    final anchor = financePeriod.anchor;
    final today = _today;
    final siteId = widget.restaurantId;
    final accessible = _restaurants.where((site) => session.canAccessRestaurant(site.id)).toList()..sort(compareSiteIds);
    final site = accessible.where((item) => item.id == siteId).firstOrNull;
    final f = FinanceFormats(site?.currency ?? 'EUR');

    final currentRange = periodRange(period, anchor);
    final previousRange = previousRangeFor(period, anchor, today);
    final comparisonText = comparisonTextFor(period, anchor, today);
    final buckets = timeBuckets(period, anchor);

    List<DailyFinancial> rowsIn(String from, String to) => rowsInRange(_rows, from, to, (id) => id == siteId);

    final currentRows = rowsIn(currentRange.from, currentRange.to);
    final previousRows = rowsIn(previousRange.from, previousRange.to);
    final totals = sumTotals(currentRows);
    final previousTotals = sumTotals(previousRows);
    final comparable = isComparable(currentRows, previousRows);

    double? delta(double current, double previous) {
      if (!comparable || previous == 0) return null;
      return (current - previous) / previous.abs();
    }

    double share(double part) => totals.revenue > 0 ? part / totals.revenue : 0;

    final tiles = [
      FinanceTile(
        label: 'Ingresos',
        value: f.money(totals.revenue),
        hint: '${totals.days} días con ventas',
        delta: delta(totals.revenue, previousTotals.revenue),
        comparisonText: comparisonText,
      ),
      FinanceTile(
        label: 'Gastos',
        value: f.money(totals.costs),
        hint: '${FinanceFormats.percent(share(totals.costs))} de los ingresos',
        delta: delta(totals.costs, previousTotals.costs),
        comparisonText: comparisonText,
        upIsGood: false,
      ),
      FinanceTile(
        label: 'Ganancia neta',
        value: f.money(totals.profit),
        hint: 'Margen ${FinanceFormats.percent(share(totals.profit))}',
        delta: delta(totals.profit, previousTotals.profit),
        comparisonText: comparisonText,
      ),
      FinanceTile(
        label: 'Ticket promedio',
        value: f.money(ticketOf(totals)),
        hint: '${FinanceFormats.integer(totals.orders)} pedidos',
        delta: delta(ticketOf(totals), ticketOf(previousTotals)),
        comparisonText: comparisonText,
      ),
      FinanceTile(
        label: 'Comensales',
        value: FinanceFormats.integer(totals.guests),
        hint: '${f.money(totals.guests > 0 ? totals.revenue / totals.guests : 0)} por comensal',
        delta: delta(totals.guests.toDouble(), previousTotals.guests.toDouble()),
        comparisonText: comparisonText,
      ),
    ];

    final expenses = [
      for (final category in _expenseCategories)
        (
          key: category.key,
          label: category.label,
          hint: category.hint,
          amount: _expenseValue(totals, category.key),
          ofRevenue: share(_expenseValue(totals, category.key)),
          delta: delta(_expenseValue(totals, category.key), _expenseValue(previousTotals, category.key)),
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    final maxExpense = expenses.fold<double>(1, (value, item) => math.max(value, item.amount));

    // Cascada de ingresos a ganancia: cada gasto resta desde el total acumulado.
    final revenue = totals.revenue;
    final scale = [revenue, revenue - math.min(0, totals.profit), 1.0].reduce(math.max);
    var running = revenue;
    final steps = [
      for (final item in expenses)
        () {
          running -= item.amount;
          return (key: item.key, label: item.label, amount: -item.amount, left: math.max(0, running) / scale, width: item.amount / scale);
        }(),
    ];

    final methods = [
      for (var index = 0; index < _methodOrder.length; index++)
        (
          key: _methodOrder[index],
          label: paymentMethodLabel[_methodOrder[index]] ?? _methodOrder[index],
          color: seriesColor(context, index + 1),
          amount: totals.byMethod[_methodOrder[index]],
          share: share(totals.byMethod[_methodOrder[index]]),
        ),
    ].where((item) => item.amount > 0).toList();

    final partialKey = partialBucketKey(period, buckets, today);
    List<double?> point(double Function(FinanceTotals value) pick) => [
          for (final bucket in buckets)
            bucket.from.compareTo(today) > 0 ? null : pick(sumTotals(rowsIn(bucket.from, bucket.to))).roundToDouble(),
        ];
    final lineSeries = [
      LineSeries(id: 'revenue', label: 'Ingresos', color: seriesColor(context, 1), values: point((value) => value.revenue)),
      LineSeries(id: 'costs', label: 'Gastos', color: seriesColor(context, 2), values: point((value) => value.costs)),
      LineSeries(id: 'profit', label: 'Ganancia', color: seriesColor(context, 3), values: point((value) => value.profit)),
    ];
    final chartLabels = [for (final bucket in buckets) bucket.key == partialKey ? '${bucket.label} (en curso)' : bucket.label];

    // Una fila por día (o por mes en la vista anual), de la más reciente a la más antigua.
    final breakdown = buckets
        .where((bucket) => bucket.from.compareTo(today) <= 0)
        .map((bucket) => (bucket: bucket, totals: sumTotals(rowsIn(bucket.from, bucket.to))))
        .toList()
        .reversed
        .toList();

    Widget waterfallRow({required String label, required Widget bar, required String value, bool strong = false, Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                  color: strong ? c.onSurface : c.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 20, child: bar)),
            const SizedBox(width: 8),
            SizedBox(
              width: 84,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                  color: valueColor ?? (strong ? c.onSurface : c.onSurfaceVariant),
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget fractionBar({required double left, required double width, required Color color, BorderRadius? radius, double inset = 0}) {
      return LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              left: left.clamp(0, 1) * constraints.maxWidth,
              top: inset,
              bottom: inset,
              width: width.clamp(0, 1) * constraints.maxWidth,
              child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: radius ?? BorderRadius.circular(3))),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(Uri(path: Routes.finance, queryParameters: financePeriod.periodQuery()).toString()),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Finanzas'),
            ),
          ),
          Text('DETALLE DEL LOCAL', style: AppFonts.eyebrow(color: c.tertiary)),
          Text(site?.name ?? 'Local', style: AppFonts.headline(fontSize: 28, color: c.onSurface)),
          Text(capitalizeFirst(periodLabel(period, anchor)), style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          if (accessible.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(siteId),
              initialValue: accessible.any((item) => item.id == siteId) ? siteId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Local'),
              items: [for (final item in accessible) DropdownMenuItem(value: item.id, child: Text(item.name))],
              onChanged: (value) {
                if (value != null && value != siteId) _changeSite(value);
              },
            ),
          ],
          const SizedBox(height: 16),
          FinancePeriodPicker(
            period: period,
            anchor: anchor,
            onPeriodChanged: (value) => financePeriod.period = value,
            onAnchorChanged: (value) => financePeriod.anchor = value,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const SkeletonBlock(rows: 5)
          else if (_loadError)
            const InlineAlert('No pudimos cargar los datos financieros. Revisa tu conexión e inténtalo de nuevo.')
          else
            AnimatedOpacity(
              opacity: _isRefreshing ? 0.5 : 1,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TwoColumnGrid(children: tiles),
                  const SizedBox(height: 16),
                  if (totals.days == 0)
                    NoSalesNotice(period: period)
                  else ...[
                    FinanceSection(
                      title: 'De ingresos a ganancia',
                      description: 'Cada gasto descuenta del total hasta llegar a la ganancia.',
                      children: [
                        waterfallRow(
                          label: 'Ingresos',
                          strong: true,
                          value: f.money(totals.revenue),
                          bar: fractionBar(
                            left: 0,
                            width: revenue / scale,
                            color: seriesColor(context, 1),
                            radius: const BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                        for (final step in steps)
                          waterfallRow(
                            label: '− ${step.label}',
                            value: f.money(step.amount),
                            bar: fractionBar(
                              left: step.left,
                              width: math.max(step.width, 0.006),
                              color: c.onSurfaceVariant.withValues(alpha: 0.35),
                              inset: 2,
                            ),
                          ),
                        Divider(height: 12, color: c.outlineVariant.withValues(alpha: 0.5)),
                        waterfallRow(
                          label: 'Ganancia',
                          strong: true,
                          value: f.money(totals.profit),
                          valueColor: totals.profit < 0 ? c.error : null,
                          bar: fractionBar(
                            left: 0,
                            width: totals.profit.abs() / scale,
                            color: totals.profit >= 0 ? seriesColor(context, 3) : c.error,
                            radius: const BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FinanceSection(
                      title: 'Ingresos por método de pago',
                      description: 'Cómo te pagaron los clientes en este período.',
                      children: [
                        // Barra 100% con separación de 2px entre segmentos.
                        Semantics(
                          label: methods.map((item) => '${item.label} ${FinanceFormats.percent(item.share)}').join(', '),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 24,
                              child: Row(
                                children: [
                                  for (var index = 0; index < methods.length; index++) ...[
                                    if (index > 0) const SizedBox(width: 2),
                                    Expanded(
                                      flex: math.max(1, (methods[index].share * 1000).round()),
                                      child: ColoredBox(color: methods[index].color),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final item in methods)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item.label, style: TextStyle(color: c.onSurface))),
                                Text(
                                  f.money(item.amount),
                                  style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface, fontFeatures: tabularFigures),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    FinanceFormats.percent(item.share),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant, fontFeatures: tabularFigures),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FinanceSection(
                      title: 'Gastos por categoría',
                      description: 'Total ${f.money(totals.costs)} · ${FinanceFormats.percent(share(totals.costs))} de los ingresos',
                      children: [
                        for (final item in expenses)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.label, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
                                          Text(item.hint, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          f.money(item.amount),
                                          style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface, fontFeatures: tabularFigures),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              FinanceFormats.percent(item.ofRevenue),
                                              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant, fontFeatures: tabularFigures),
                                            ),
                                            const SizedBox(width: 8),
                                            if (item.delta != null)
                                              // En gastos, bajar es bueno.
                                              DeltaText(delta: item.delta!, upIsGood: false, showIcon: false)
                                            else
                                              Text('—', style: TextStyle(fontSize: 12, color: c.outline)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: item.amount / maxExpense,
                                    minHeight: 8,
                                    color: seriesColor(context, 2),
                                    backgroundColor: c.surfaceContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Porcentaje = parte de los ingresos. Variación $comparisonText (bajar un gasto se marca en verde).',
                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FinanceSection(
                      title: 'Ingresos, gastos y ganancia',
                      description: evolutionTitles[period],
                      children: [
                        FinanceLineChart(
                          labels: chartLabels,
                          series: lineSeries,
                          format: f.money,
                          formatAxis: f.compact,
                          partialIndex: partialKey == null ? null : buckets.indexWhere((bucket) => bucket.key == partialKey),
                          description: 'Ingresos, gastos y ganancia de ${site?.name ?? 'el local'}. Los valores están en la tabla de abajo.',
                        ),
                        if (partialKey != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'El mes en curso solo incluye hasta hoy, por eso se ve más bajo.',
                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Detalle ${period == 'year' ? 'por mes' : 'por día'}', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                    const SizedBox(height: 10),
                    for (final entry in breakdown) ...[
                      _BreakdownCard(label: _dateLabel(entry.bucket.key), totals: entry.totals, formats: f),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.label, required this.totals, required this.formats});

  final String label;
  final FinanceTotals totals;
  final FinanceFormats formats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = formats;
    final hasSales = totals.days > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface))),
              if (hasSales)
                Text(
                  f.money(totals.profit),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: totals.profit < 0 ? c.error : c.onSurface,
                    fontFeatures: tabularFigures,
                  ),
                )
              else
                Text('Cerrado / sin ventas', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: c.onSurfaceVariant)),
            ],
          ),
          if (hasSales)
            FigureGrid(
              cells: [
                FigureCell(label: 'Ingresos', value: f.money(totals.revenue)),
                FigureCell(label: 'Insumos', value: f.money(totals.foodCost)),
                FigureCell(label: 'Personal', value: f.money(totals.laborCost)),
                FigureCell(label: 'Operación', value: f.money(totals.operatingCost)),
                FigureCell(label: 'Pedidos', value: FinanceFormats.integer(totals.orders)),
              ],
            ),
        ],
      ),
    );
  }
}
