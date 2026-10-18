import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../stores/site_activity_store.dart';
import '../../../widgets/base/base_pagination.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../expenses/widgets/expenses_panel.dart';
import '../../payments/account.dart';
import '../../payments/api.dart';
import '../../payments/types.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../types.dart';
import '../widgets/account_dialog.dart';
import '../widgets/service_ui.dart';

class _AccountRow {
  const _AccountRow({required this.attention, required this.account, required this.requestedAt});

  final AttentionWithProducts attention;
  final AccountSummary account;

  /// Momento en que el comensal pidió la cuenta.
  final String? requestedAt;
}

/// 'active' | 'requested' | 'closed' | 'all'
typedef _AccountFilter = String;

const List<(_AccountFilter, String)> _filters = [
  ('active', 'Activas'),
  ('requested', 'Pidieron la cuenta'),
  ('closed', 'Cerradas y canceladas'),
  ('all', 'Todas'),
];

/// Cuentas y cobros de la sede (pestaña "Cobros") y gastos del local (pestaña "Gastos", `?vista=gastos`).
/// Con [attentionId] (ruta `cuentas/:attentionId`) abre la cuenta de esa atención.
class SiteAccountsView extends StatefulWidget {
  const SiteAccountsView({super.key, required this.siteSlug, this.attentionId, this.view});

  final String siteSlug;
  final String? attentionId;
  final String? view;

  @override
  State<SiteAccountsView> createState() => _SiteAccountsViewState();
}

class _SiteAccountsViewState extends State<SiteAccountsView> {
  late final SiteContext _site;
  late final SiteActivityStore _activity;
  late int _lastRevision;

  final ValueNotifier<List<AttentionWithProducts>> _attentions = ValueNotifier(const []);
  List<Payment> _payments = const [];
  Map<String, String> _requestedAtById = const {};
  String? _actionError;

  /// 'cobros' | 'gastos'
  late String _tab = widget.view == 'gastos' ? 'gastos' : 'cobros';
  _AccountFilter _filter = 'active';
  final TextEditingController _search = TextEditingController();
  int _page = 1;
  int _pageSize = 15;
  int _now = nowMs();
  Timer? _clock;
  bool _routeDetailHandled = false;

  /// Cambia para recrear el panel de gastos (recarga al tirar hacia abajo).
  int _expensesGeneration = 0;

  @override
  void initState() {
    super.initState();
    _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadAccounts)..addListener(_onSiteChanged);
    _activity = context.read<SiteActivityStore>();
    _lastRevision = _activity.revision;
    _activity.addListener(_onActivity);
    _search.addListener(() => setState(() => _page = 1));
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = nowMs());
    });
    unawaited(_site.load());
  }

  @override
  void didUpdateWidget(covariant SiteAccountsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.siteSlug != widget.siteSlug) {
      unawaited(_site.setSlug(widget.siteSlug));
    }

    if (oldWidget.view != widget.view) {
      setState(() => _tab = widget.view == 'gastos' ? 'gastos' : 'cobros');
    }

    if (oldWidget.attentionId != widget.attentionId) {
      _routeDetailHandled = false;
      _maybeOpenRouteDetail();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _activity.removeListener(_onActivity);
    _site.removeListener(_onSiteChanged);
    _site.dispose();
    _attentions.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSiteChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeOpenRouteDetail();
  }

  void _onActivity() {
    if (_activity.revision != _lastRevision) {
      _lastRevision = _activity.revision;
      unawaited(_reload());
    }
  }

  Future<void> _loadAccounts([RestaurantSite? site]) async {
    final id = site?.id ?? _site.restaurantId;

    if (id == null) {
      return;
    }

    final results = await Future.wait<Object>([fetchAttentionsWithProductsBySite(id), fetchAllPayments(), fetchAllStatusHistory()]);
    final siteAttentions = results[0] as List<AttentionWithProducts>;
    final allPayments = results[1] as List<Payment>;
    final history = results[2] as List<StatusHistoryEntry>;
    final ids = siteAttentions.map((attention) => attention.id).toSet();
    final requested = <String, String>{};

    for (final entry in history) {
      if (entry.entityType == 'attention' && entry.toStatus == 'account-requested' && ids.contains(entry.entityId)) {
        requested[entry.entityId] = entry.changedAt;
      }
    }

    if (!mounted) return;
    setState(() {
      _payments = allPayments.where((payment) => ids.contains(payment.attentionId)).toList();
      _requestedAtById = requested;
    });
    _attentions.value = siteAttentions;
  }

  Future<void> _reload() async {
    try {
      await _loadAccounts();
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudieron actualizar las cuentas.'));
    }
  }

  Future<void> _handleChanged() async {
    await _reload();
    unawaited(_activity.refresh());
  }

  void _maybeOpenRouteDetail() {
    final id = widget.attentionId;

    if (id == null || _routeDetailHandled || _site.isLoading || _site.restaurant == null) {
      return;
    }

    final attention = _attentions.value.where((item) => item.id == id).firstOrNull;

    if (attention == null) {
      return;
    }

    _routeDetailHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openAccount(attention, fromRoute: true));
    });
  }

  Future<void> _openAccount(AttentionWithProducts attention, {bool fromRoute = false}) async {
    final restaurant = _site.restaurant;

    if (restaurant == null) {
      return;
    }

    await showAccountDialog(
      context,
      attention: attention,
      source: _attentions,
      currency: _site.currency,
      timezone: restaurant.timezone,
      onChanged: _handleChanged,
    );

    if (fromRoute && mounted) {
      context.go(Routes.siteAccounts(widget.siteSlug));
    }
  }

  List<_AccountRow> get _rows => [
    for (final attention in _attentions.value)
      _AccountRow(
        attention: attention,
        account: computeAccount(attention.products, _payments.where((payment) => payment.attentionId == attention.id).toList()),
        requestedAt: _requestedAtById[attention.id],
      ),
  ];

  /// Primero las que pidieron la cuenta (la más antigua arriba), luego abiertas y al final las cerradas recientes.
  int _sortRank(_AccountRow row) {
    if (row.attention.status == 'account-requested') return 0;
    return row.attention.status == 'open' ? 1 : 2;
  }

  bool _matchesFilter(_AccountRow row, _AccountFilter filter) => switch (filter) {
    'active' => isAttentionActive(row.attention),
    'requested' => row.attention.status == 'account-requested',
    'closed' => !isAttentionActive(row.attention),
    _ => true,
  };

  List<_AccountRow> _tableRows(List<_AccountRow> rows) {
    final term = _search.text.trim().toLowerCase();

    return rows
        .where((row) => _matchesFilter(row, _filter))
        .where((row) => term.isEmpty || 'mesa ${row.attention.tableNumber} ${row.attention.guestName ?? ''}'.toLowerCase().contains(term))
        .toList()
      ..sort((a, b) {
        final rank = _sortRank(a) - _sortRank(b);
        if (rank != 0) return rank;
        if (_sortRank(a) == 0) return (a.requestedAt ?? '').compareTo(b.requestedAt ?? '') < 0 ? -1 : 1;
        if (_sortRank(a) == 1) return a.attention.openedAt.compareTo(b.attention.openedAt) < 0 ? -1 : 1;
        return (a.attention.closedAt ?? a.attention.openedAt).compareTo(b.attention.closedAt ?? b.attention.openedAt) < 0 ? 1 : -1;
      });
  }

  String _formatClosedAt(String iso) => DateFormat('d MMM, HH:mm', 'es').format(inZone(parseIso(iso), _site.restaurant?.timezone));

  Future<void> _refresh() async {
    if (_tab == 'gastos') {
      setState(() => _expensesGeneration += 1);
      return;
    }

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final restaurant = _site.restaurant;
    final rows = _rows;
    final openTotal = rows.where((row) => isAttentionActive(row.attention)).fold<double>(0, (sum, row) => sum + row.account.remaining);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          if (_site.isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_site.loadError != null)
            InlineAlert(_site.loadError!)
          else if (restaurant != null) ...[
            SitePageHeader(
              restaurant: restaurant,
              section: 'Cuentas',
              title: _tab == 'gastos' ? 'Gastos de la sede' : 'Cuentas y cobros',
              description: _tab == 'gastos' ? 'Registra insumos, sueldos, alquiler, servicios y demás gastos del local, mes a mes.' : 'Las mesas que pidieron la cuenta aparecen primero. Registra uno o varios pagos; la cuenta se cierra sola cuando el saldo llega a cero.',
              actions: [
                if (_tab == 'cobros')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PENDIENTE POR COBRAR', style: AppFonts.label(fontSize: 11, color: c.onSurfaceVariant, letterSpacing: 0.8)),
                        Text(formatMoney(openTotal, _site.currency), style: tabular(AppFonts.headline(fontSize: 18, color: c.onSurface))),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'cobros', label: Text('Cobros')),
                ButtonSegment(value: 'gastos', label: Text('Gastos')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
            const SizedBox(height: 16),
            if (_tab == 'gastos' && _site.restaurantId != null)
              ExpensesPanel(key: ValueKey('expenses-$_expensesGeneration'), restaurantId: _site.restaurantId!, currency: _site.currency)
            else
              ..._charges(context, rows),
          ],
        ],
      ),
    );
  }

  List<Widget> _charges(BuildContext context, List<_AccountRow> rows) {
    final c = context.colors;
    final tableRows = _tableRows(rows);
    final paged = tableRows.skip((_page - 1) * _pageSize).take(_pageSize).toList();
    final counts = {for (final (id, _) in _filters) id: rows.where((row) => _matchesFilter(row, id)).length};

    return [
      if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (id, label) in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: _filter == id,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() {
                    _filter = id;
                    _page = 1;
                  }),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      const SizedBox(width: 6),
                      Pill(
                        '${counts[id]}',
                        background: id == 'requested' && counts['requested']! > 0
                            ? c.error
                            : c.surfaceContainerLowest.withValues(alpha: 0.7),
                        foreground: id == 'requested' && counts['requested']! > 0 ? c.onError : c.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(hintText: 'Buscar mesa', prefixIcon: Icon(Icons.search_rounded)),
      ),
      const SizedBox(height: 12),
      if (tableRows.isEmpty)
        SurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filter == 'requested' ? 'Ninguna mesa está esperando la cuenta.' : 'No hay cuentas que coincidan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
          ),
        )
      else ...[
        for (final row in paged) ...[_accountCard(context, row), const SizedBox(height: 10)],
        const SizedBox(height: 4),
        BasePagination(
          total: tableRows.length,
          page: _page,
          pageSize: _pageSize,
          itemLabel: 'cuentas',
          onPageChanged: (page) => setState(() => _page = page),
          onPageSizeChanged: (size) => setState(() => _pageSize = size),
        ),
      ],
    ];
  }

  Widget _accountCard(BuildContext context, _AccountRow row) {
    final c = context.colors;
    final attention = row.attention;
    final requested = attention.status == 'account-requested';
    final active = isAttentionActive(attention);
    final money = tabular(TextStyle(fontSize: 14, color: c.onSurface));

    final Widget time;
    if (requested && row.requestedAt != null) {
      time = Text(
        'Pidió ${formatElapsed(row.requestedAt!, _now)}',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.onTertiaryContainer),
      );
    } else if (active) {
      time = Text('Abierta ${formatElapsed(attention.openedAt, _now)}', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant));
    } else if (attention.closedAt != null) {
      time = Text('Cerró ${_formatClosedAt(attention.closedAt!)}', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant));
    } else {
      time = Text('—', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant));
    }

    Widget figure(String label, String value, Color color, {bool bold = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppFonts.label(fontSize: 10, color: c.onSurfaceVariant, letterSpacing: 0.6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: money.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      borderColor: requested ? c.tertiaryContainer : null,
      color: requested ? Color.alphaBlend(c.tertiaryFixed.withValues(alpha: 0.25), c.surfaceContainerLowest) : null,
      onTap: () => _openAccount(attention),
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
                    Text('Mesa ${attention.tableNumber}', style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
                    if ((attention.guestName ?? '').isNotEmpty)
                      Text(attention.guestName!, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              StatusBadge(
                tone: attentionStatusTone[attention.status] ?? 'neutral',
                label: attentionStatusLabel[attention.status] ?? attention.status,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: time),
              Text('${attention.products.length} productos', style: tabular(TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              figure('Total', formatMoney(row.account.total, _site.currency), c.onSurface),
              figure('Pagado', formatMoney(row.account.paid, _site.currency), row.account.paid > 0 ? c.success : c.onSurfaceVariant),
              figure(
                'Pendiente',
                formatMoney(row.account.remaining, _site.currency),
                row.account.remaining > 0 ? c.onSurface : c.onSurfaceVariant,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: requested
                ? FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: c.primary, foregroundColor: c.onPrimary),
                    onPressed: () => _openAccount(attention),
                    child: const Text('Cobrar →'),
                  )
                : TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _openAccount(attention),
                    child: Text(active ? 'Ver cuenta' : 'Detalle', style: AppFonts.label(fontSize: 14, color: c.primary)),
                  ),
          ),
        ],
      ),
    );
  }
}
