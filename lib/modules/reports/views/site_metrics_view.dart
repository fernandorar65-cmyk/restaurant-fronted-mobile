import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../administration/widgets/admin_form.dart';
import '../../orders/api.dart';
import '../../orders/types.dart';
import '../../payments/api.dart';
import '../../payments/types.dart';
import '../../restaurants/types.dart';
import '../metrics.dart';
import '../widgets/ranked_bars.dart';

const List<({MetricsPeriod id, String label})> _periods = [
  (id: 'today', label: 'Hoy'),
  (id: 'week', label: 'Últimos 7 días'),
  (id: 'all', label: 'Todo'),
];

String _minutes(double? value) {
  if (value == null) return '—';
  final text = value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$text min';
}

/// Métricas operativas de una sede (equivale a SiteMetricsView.vue).
class SiteMetricsView extends StatefulWidget {
  const SiteMetricsView({super.key, required this.siteSlug});

  final String siteSlug;

  @override
  State<SiteMetricsView> createState() => _SiteMetricsViewState();
}

class _SiteMetricsViewState extends State<SiteMetricsView> {
  late final SiteContext _site;
  List<Attention> _attentions = [];
  List<OrderedProduct> _products = [];
  List<StatusHistoryEntry> _history = [];
  List<Payment> _payments = [];
  MetricsPeriod _period = 'week';

  @override
  void initState() {
    super.initState();
    _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadData)..addListener(_onSiteChanged);
    _site.load();
  }

  @override
  void didUpdateWidget(covariant SiteMetricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteSlug != widget.siteSlug) _site.setSlug(widget.siteSlug);
  }

  @override
  void dispose() {
    _site.removeListener(_onSiteChanged);
    _site.dispose();
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData(RestaurantSite site) async {
    final results = await Future.wait<Object>([
      fetchAttentionsBySite(site.id),
      fetchOrderedProductsBySite(site.id),
      fetchAllStatusHistory(),
      fetchAllPayments(),
    ]);
    _attentions = results[0] as List<Attention>;
    _products = results[1] as List<OrderedProduct>;
    _history = results[2] as List<StatusHistoryEntry>;
    _payments = results[3] as List<Payment>;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final restaurant = _site.restaurant;

    return RefreshIndicator(
      onRefresh: _site.reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_site.isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_site.loadError != null)
            InlineAlert(_site.loadError!)
          else if (restaurant != null)
            ..._content(c, restaurant),
        ],
      ),
    );
  }

  List<Widget> _content(AppColors c, RestaurantSite restaurant) {
    final currency = _site.currency;
    final metrics = computeSiteMetrics(
      attentions: _attentions,
      products: _products,
      history: _history,
      payments: _payments,
      period: _period,
      timeZone: restaurant.timezone,
    );

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(text, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
        );

    Widget card(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        );

    return [
      SitePageHeader(
        restaurant: restaurant,
        section: 'Métricas',
        title: 'Métricas operativas',
        description: 'Tiempos de servicio, ventas y comportamiento de la carta, calculados con los pedidos registrados.',
        actions: [
          SegmentedButton<MetricsPeriod>(
            showSelectedIcon: false,
            segments: [for (final option in _periods) ButtonSegment(value: option.id, label: Text(option.label))],
            selected: {_period},
            onSelectionChanged: (selection) => setState(() => _period = selection.first),
          ),
          BaseButton(label: 'Actualizar', icon: Icons.refresh_rounded, size: 'sm', onPressed: _site.reload),
        ],
      ),
      sectionTitle('Tiempos promedio'),
      TwoColumnGrid(
        children: [
          StatTile(label: 'Pedido → confirmación', value: _minutes(metrics.minutesToConfirm)),
          StatTile(label: 'Confirmación → listo', value: _minutes(metrics.minutesToReady)),
          StatTile(label: 'Listo → entregado', value: _minutes(metrics.minutesToDeliver)),
          StatTile(label: 'Pedido → entrega (total)', value: _minutes(metrics.minutesEndToEnd)),
        ],
      ),
      sectionTitle('Ventas y mesas'),
      TwoColumnGrid(
        children: [
          StatTile(
            label: 'Ventas cobradas',
            value: formatMoney(metrics.sales, currency),
            hint: '${metrics.attentionsClosed} cuentas cerradas',
          ),
          StatTile(
            label: 'Ticket promedio',
            value: metrics.averageTicket == null ? '—' : formatMoney(metrics.averageTicket!, currency),
          ),
          StatTile(
            label: 'Duración de una atención',
            value: _minutes(metrics.averageAttentionMinutes),
            hint: '${metrics.attentionsCancelled} canceladas',
          ),
          StatTile(
            label: 'Rotación de mesas',
            value: metrics.tableTurnover == null ? '—' : '${metrics.tableTurnover}'.replaceAll('.', ','),
            hint: 'cuentas cerradas por mesa usada',
          ),
        ],
      ),
      card('Más pedidos (unidades)', [RankedBars(items: metrics.topProducts, unit: 'uds')]),
      card('Más rechazados', [
        RankedBars(items: metrics.rejectedProducts, unit: 'uds', emptyLabel: 'Ningún producto rechazado en este período.'),
      ]),
      card('Origen de los pedidos', [
        Text(
          metrics.qrShare == null ? '—' : '${metrics.qrShare}%',
          style: AppFonts.headline(fontSize: 36, color: c.onSurface).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        Text('de los productos se pidieron por QR.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        const SizedBox(height: 12),
        RankedBars(
          items: [
            RankedItem(label: 'Por QR (comensal)', value: metrics.qrCount),
            RankedItem(label: 'Manual (personal)', value: metrics.manualCount),
          ],
          unit: 'productos',
        ),
      ]),
    ];
  }
}
