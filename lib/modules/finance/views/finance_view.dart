import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../administration/widgets/admin_form.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../period.dart';
import '../types.dart';
import '../widgets/finance_bar_chart.dart';
import '../widgets/finance_formats.dart';
import '../widgets/finance_line_chart.dart';
import '../widgets/finance_period_picker.dart';
import '../widgets/finance_shared.dart';

/// Ordena las sedes por id numérico (como el front web), con respaldo alfabético.
int compareSiteIds(RestaurantSite a, RestaurantSite b) {
  final left = int.tryParse(a.id);
  final right = int.tryParse(b.id);
  if (left != null && right != null) return left.compareTo(right);
  return a.id.compareTo(b.id);
}

/// Finanzas de la cadena: ingresos, ganancia y evolución por local (equivale a FinanceView.vue).
class FinanceView extends StatefulWidget {
  const FinanceView({super.key});

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> with FinancePeriodQuery<FinanceView> {
  /// 'profit' | 'revenue'
  String _metric = 'profit';
  List<RestaurantSite> _restaurants = [];
  List<String> _selectedIds = [];
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
      if (mounted) _selectAll();
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
      // Si el período cambió mientras cargaba, gana el pedido más reciente.
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

  /// Sedes a las que el usuario tiene acceso, en orden fijo por id.
  List<RestaurantSite> _accessibleSites(SessionStore session) =>
      _restaurants.where((site) => session.canAccessRestaurant(site.id)).toList()..sort(compareSiteIds);

  void _selectAll() {
    setState(() => _selectedIds = _accessibleSites(context.read<SessionStore>()).map((site) => site.id).toList());
  }

  void _toggleSite(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        // Siempre queda al menos una sede seleccionada.
        if (_selectedIds.length > 1) _selectedIds = _selectedIds.where((item) => item != id).toList();
      } else {
        _selectedIds = [..._selectedIds, id];
      }
    });
  }

  /// Detalle de ingresos y gastos de un local, con el mismo período.
  void _openSite(String siteId) {
    context.go(Uri(path: Routes.financeSite(siteId), queryParameters: financePeriod.periodQuery()).toString());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final period = financePeriod.period;
    final anchor = financePeriod.anchor;
    final today = _today;
    final accessible = _accessibleSites(session);

    // El color sigue a la sede, no a su posición: filtrar no repinta a las demás.
    Color siteColor(String siteId) => seriesColor(context, accessible.indexWhere((site) => site.id == siteId) % 8 + 1);

    final selectedSites = accessible.where((site) => _selectedIds.contains(site.id)).toList();
    final currency = selectedSites.firstOrNull?.currency ?? accessible.firstOrNull?.currency ?? 'EUR';
    final f = FinanceFormats(currency);
    final allSelected = _selectedIds.length == accessible.length;

    final currentRange = periodRange(period, anchor);
    final previousRange = previousRangeFor(period, anchor, today);
    final comparisonText = comparisonTextFor(period, anchor, today);
    final buckets = timeBuckets(period, anchor);

    List<DailyFinancial> rowsIn(String from, String to, [List<String>? siteIds]) =>
        rowsInRange(_rows, from, to, (id) => (siteIds ?? _selectedIds).contains(id));

    final currentRows = rowsIn(currentRange.from, currentRange.to);
    final previousRows = rowsIn(previousRange.from, previousRange.to);
    final totals = sumTotals(currentRows);
    final previousTotals = sumTotals(previousRows);
    final comparable = isComparable(currentRows, previousRows);

    double? delta(double current, double previous) {
      if (!comparable || previous == 0) return null;
      return (current - previous) / previous.abs();
    }

    final tiles = [
      FinanceTile(
        label: 'Ingresos',
        value: f.money(totals.revenue),
        hint: '${FinanceFormats.integer(totals.days)} cierres diarios',
        delta: delta(totals.revenue, previousTotals.revenue),
        comparisonText: comparisonText,
      ),
      FinanceTile(
        label: 'Ganancia neta',
        value: f.money(totals.profit),
        hint: 'Margen ${FinanceFormats.percent(marginOf(totals))}',
        delta: delta(totals.profit, previousTotals.profit),
        comparisonText: comparisonText,
      ),
      FinanceTile(
        label: 'Pedidos',
        value: FinanceFormats.integer(totals.orders),
        hint: 'Tickets cobrados',
        delta: delta(totals.orders.toDouble(), previousTotals.orders.toDouble()),
        comparisonText: comparisonText,
      ),
      FinanceTile(
        label: 'Ticket promedio',
        value: f.money(ticketOf(totals)),
        hint: 'Ingresos ÷ pedidos',
        delta: delta(ticketOf(totals), ticketOf(previousTotals)),
        comparisonText: comparisonText,
      ),
    ];

    // Totales por sede, ordenados por ganancia.
    final perSite = selectedSites
        .map((site) => (site: site, totals: sumTotals(rowsIn(currentRange.from, currentRange.to, [site.id]))))
        .toList()
      ..sort((a, b) => b.totals.profit.compareTo(a.totals.profit));
    // Sedes sin ventas en el período (p. ej. inactivas): se omiten de los gráficos.
    final withData = perSite.where((entry) => entry.totals.days > 0).toList();
    final sitesWithoutData = perSite.where((entry) => entry.totals.days == 0).map((entry) => entry.site.name).toList();

    final barItems = [
      for (final entry in withData)
        BarItem(
          id: entry.site.id,
          label: entry.site.name,
          color: siteColor(entry.site.id),
          value: entry.totals.profit,
          details: [
            (label: 'Ingresos', value: f.money(entry.totals.revenue)),
            (label: 'Costos', value: f.money(entry.totals.costs)),
            (label: 'Ganancia', value: f.money(entry.totals.profit)),
            (label: 'Margen', value: FinanceFormats.percent(marginOf(entry.totals))),
          ],
        ),
    ];

    double? bucketValue(TimeBucket bucket, String siteId) {
      // Días o meses que todavía no llegan quedan sin dato (la línea se corta).
      if (bucket.from.compareTo(today) > 0) return null;
      final value = sumTotals(rowsIn(bucket.from, bucket.to, [siteId]));
      return (_metric == 'profit' ? value.profit : value.revenue).roundToDouble();
    }

    final lineSeries = [
      for (final entry in withData)
        LineSeries(
          id: entry.site.id,
          label: entry.site.name,
          color: siteColor(entry.site.id),
          values: [for (final bucket in buckets) bucketValue(bucket, entry.site.id)],
        ),
    ];

    final evolutionTitle = evolutionTitles[period] ?? '';
    final partialKey = partialBucketKey(period, buckets, today);
    final chartLabels = [for (final bucket in buckets) bucket.key == partialKey ? '${bucket.label} (en curso)' : bucket.label];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('CADENA', style: AppFonts.eyebrow(color: c.tertiary)),
          Text('Finanzas', style: AppFonts.title(fontSize: 30, color: c.heading)),
          Text(capitalizeFirst(periodLabel(period, anchor)), style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          const SizedBox(height: 16),
          FinancePeriodPicker(
            period: period,
            anchor: anchor,
            onPeriodChanged: (value) => financePeriod.period = value,
            onAnchorChanged: (value) => financePeriod.anchor = value,
          ),
          if (accessible.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(label: const Text('Todos'), selected: allSelected, onSelected: (_) => _selectAll()),
                  for (final site in accessible)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        avatar: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: siteColor(site.id), shape: BoxShape.circle),
                        ),
                        showCheckmark: false,
                        label: Text(site.name),
                        selected: _selectedIds.contains(site.id),
                        onSelected: (_) => _toggleSite(site.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_isLoading)
            const SkeletonBlock(rows: 5)
          else if (_loadError)
            const InlineAlert('No pudimos cargar los datos financieros. Revisa tu conexión e inténtalo de nuevo.')
          else
            // Al recargar se mantiene el contenido anterior atenuado, sin saltos.
            AnimatedOpacity(
              opacity: _isRefreshing ? 0.5 : 1,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TwoColumnGrid(children: tiles),
                  if (totals.days == 0) ...[
                    const SizedBox(height: 16),
                    NoSalesNotice(period: period),
                  ],
                  const SizedBox(height: 16),
                  FinanceSection(
                    title: 'Ganancia por local',
                    description:
                        'Ingresos menos insumos, personal y operación. Toca un local para ver su detalle; mantenlo presionado para ver sus cifras.',
                    children: [FinanceBarChart(items: barItems, format: f.money, onSelect: _openSite)],
                  ),
                  const SizedBox(height: 16),
                  FinanceSection(
                    title: 'Evolución',
                    description: evolutionTitle,
                    trailing: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'profit', label: Text('Ganancia')),
                        ButtonSegment(value: 'revenue', label: Text('Ingresos')),
                      ],
                      selected: {_metric},
                      onSelectionChanged: (selection) => setState(() => _metric = selection.first),
                    ),
                    children: [
                      if (sitesWithoutData.isNotEmpty) ...[
                        Text(
                          'Sin ventas en este período: ${sitesWithoutData.join(', ')}.',
                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                      ],
                      FinanceLineChart(
                        labels: chartLabels,
                        series: lineSeries,
                        format: f.money,
                        formatAxis: f.compact,
                        partialIndex: partialKey == null ? null : buckets.indexWhere((bucket) => bucket.key == partialKey),
                        description:
                            '${_metric == 'profit' ? 'Ganancia' : 'Ingresos'} por local, ${evolutionTitle.toLowerCase()}. Los valores están en la tabla de detalle.',
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
                  Text('Detalle por local', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                  const SizedBox(height: 10),
                  for (final entry in perSite) ...[
                    _SiteTotalsCard(
                      title: entry.site.name,
                      color: siteColor(entry.site.id),
                      totals: entry.totals,
                      formats: f,
                      onTap: () => _openSite(entry.site.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (perSite.length > 1) _SiteTotalsCard(title: 'Total', totals: totals, formats: f, highlighted: true),
                  const SizedBox(height: 10),
                  Text(
                    'Datos de demostración generados en db.json (colección dailyFinancials). Con el backend se calcularán desde las ventas y costos reales.',
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila de la tabla "Detalle por local" como tarjeta.
class _SiteTotalsCard extends StatelessWidget {
  const _SiteTotalsCard({required this.title, required this.totals, required this.formats, this.color, this.onTap, this.highlighted = false});

  final String title;
  final Color? color;
  final FinanceTotals totals;
  final FinanceFormats formats;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = formats;

    return Material(
      color: highlighted ? c.surfaceContainerLow : c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (color != null) ...[
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface))),
                  Text(
                    f.money(totals.profit),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: totals.profit < 0 ? c.error : c.onSurface,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.outline),
                ],
              ),
              FigureGrid(
                cells: [
                  FigureCell(label: 'Ingresos', value: f.money(totals.revenue)),
                  FigureCell(label: 'Insumos', value: f.money(totals.foodCost)),
                  FigureCell(label: 'Personal', value: f.money(totals.laborCost)),
                  FigureCell(label: 'Operación', value: f.money(totals.operatingCost)),
                  FigureCell(label: 'Margen', value: FinanceFormats.percent(marginOf(totals))),
                  FigureCell(label: 'Pedidos', value: FinanceFormats.integer(totals.orders)),
                  FigureCell(label: 'Ticket prom.', value: f.money(ticketOf(totals))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
