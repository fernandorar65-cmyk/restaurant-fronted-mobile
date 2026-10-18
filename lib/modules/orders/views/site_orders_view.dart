import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../stores/site_activity_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/empty_state.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../rounds.dart';
import '../types.dart';
import '../widgets/attention_card.dart';
import '../widgets/attention_dialog.dart';
import '../widgets/order_ticket_dialog.dart';
import '../widgets/orders_board.dart';
import '../widgets/service_ui.dart';
import '../widgets/staff_order_dialog.dart';

class _IncomingRound {
  const _IncomingRound({
    required this.key,
    required this.attention,
    required this.roundNumber,
    required this.requestedAt,
    required this.createdBy,
    required this.products,
  });

  final String key;
  final AttentionWithProducts attention;
  final int roundNumber;
  final String requestedAt;
  final String? createdBy;
  final List<OrderedProduct> products;
}

/// Gestión de pedidos de la sede: tablero por estado o lista de rondas por confirmar + atenciones.
/// Con [attentionId] (ruta `pedidos/:attentionId`) abre el detalle de esa atención.
class SiteOrdersView extends StatefulWidget {
  const SiteOrdersView({super.key, required this.siteSlug, this.attentionId});

  final String siteSlug;
  final String? attentionId;

  @override
  State<SiteOrdersView> createState() => _SiteOrdersViewState();
}

class _SiteOrdersViewState extends State<SiteOrdersView> {
  late final SiteContext _site;
  late final SiteActivityStore _activity;
  late int _lastRevision;

  /// Lista viva de atenciones: las hojas abiertas la observan para refrescarse.
  final ValueNotifier<List<AttentionWithProducts>> _attentions = ValueNotifier(const []);
  final TextEditingController _rejectionReason = TextEditingController();
  bool _showClosed = false;
  String? _rejectingId;
  String? _busyKey;
  String? _actionError;

  /// 'board' | 'list'
  String _viewMode = 'board';
  int _now = nowMs();
  Timer? _clock;
  bool _routeDetailHandled = false;
  bool _initializedFromRoute = false;

  @override
  void initState() {
    super.initState();
    _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadAttentions)..addListener(_onSiteChanged);
    _activity = context.read<SiteActivityStore>();
    _lastRevision = _activity.revision;
    _activity.addListener(_onActivity);
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = nowMs());
    });
    unawaited(_site.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initializedFromRoute) {
      _initializedFromRoute = true;
      // Tablero por defecto; ?vista=lista abre la lista.
      _viewMode = GoRouterState.of(context).uri.queryParameters['vista'] == 'lista' ? 'list' : 'board';
    }
  }

  @override
  void didUpdateWidget(covariant SiteOrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.siteSlug != widget.siteSlug) {
      unawaited(_site.setSlug(widget.siteSlug));
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
    _rejectionReason.dispose();
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

  String get _staffName => context.read<SessionStore>().user?.name ?? 'Personal';

  Future<void> _loadAttentions([RestaurantSite? site]) async {
    final id = site?.id ?? _site.restaurantId;

    if (id != null) {
      final list = await fetchAttentionsWithProductsBySite(id);
      if (!mounted) return;
      _attentions.value = list;
      setState(() {});
    }
  }

  Future<void> _reload() async {
    try {
      await _loadAttentions();
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudieron actualizar los pedidos.'));
    }
  }

  /// Abre el detalle indicado por la ruta cuando ya cargaron las atenciones.
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
      if (mounted) unawaited(_openAttention(attention, fromRoute: true));
    });
  }

  List<_IncomingRound> get _incomingRounds {
    final rounds = <_IncomingRound>[
      for (final attention in _attentions.value.where(isAttentionActive))
        for (final (index, round) in groupByRound(attention.products).indexed)
          _IncomingRound(
            key: round.batchId,
            attention: attention,
            roundNumber: index + 1,
            requestedAt: round.requestedAt,
            createdBy: round.createdBy,
            products: round.products.where((product) => product.status == 'sent').toList(),
          ),
    ].where((round) => round.products.isNotEmpty).toList();

    return rounds..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
  }

  DelayLevel _roundDelay(_IncomingRound round) => delayLevel(minutesSince(round.requestedAt, _now), incomingDelayMinutes);

  void _reportFailures(List<BulkUpdateFailure> failed) {
    if (failed.isNotEmpty) {
      context.read<ToastStore>().show('Algunos productos no se actualizaron', message: failed.first.message, tone: 'warning');
    }
  }

  /// Mover una comanda del tablero al siguiente estado.
  Future<void> _advanceCard(AdvancePayload payload) async {
    setState(() {
      _busyKey = payload.key;
      _actionError = null;
    });
    final toast = context.read<ToastStore>();

    try {
      final result = await updateOrderedProductsStatus(payload.products, payload.to, _staffName);
      _reportFailures(result.failed);

      if (result.updated.isNotEmpty) {
        toast.show(
          'Mesa ${payload.tableNumber} · ${orderedProductStatusLabel[payload.to]}',
          message: '${result.updated.length} producto(s) movidos.',
          tone: 'success',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudieron actualizar los pedidos.'));
    } finally {
      if (mounted) setState(() => _busyKey = null);
      await _reload();
      unawaited(_activity.refresh());
    }
  }

  Future<void> _confirmRound(_IncomingRound round) async {
    setState(() {
      _busyKey = round.key;
      _actionError = null;
    });
    final toast = context.read<ToastStore>();

    try {
      final result = await updateOrderedProductsStatus(round.products, 'preparing', _staffName);
      _reportFailures(result.failed);

      if (result.updated.isNotEmpty) {
        toast.show('Mesa ${round.attention.tableNumber}: ${result.updated.length} producto(s) enviados a cocina', tone: 'success');
      }
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo confirmar la ronda.'));
    } finally {
      if (mounted) setState(() => _busyKey = null);
      await _reload();
    }
  }

  Future<void> _confirmProduct(OrderedProduct product) async {
    setState(() {
      _busyKey = product.id;
      _actionError = null;
    });

    try {
      await updateOrderedProductStatus(product, 'preparing', _staffName);
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo confirmar el producto.'));
    } finally {
      if (mounted) setState(() => _busyKey = null);
      await _reload();
    }
  }

  void _startReject(OrderedProduct product) {
    _rejectionReason.clear();
    setState(() => _rejectingId = product.id);
  }

  Future<void> _confirmReject(OrderedProduct product) async {
    final reason = _rejectionReason.text.trim();

    if (reason.isEmpty) {
      return;
    }

    setState(() {
      _busyKey = product.id;
      _actionError = null;
    });

    try {
      await updateOrderedProductStatus(product, 'rejected', _staffName, reason);
      if (mounted) setState(() => _rejectingId = null);
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo rechazar el producto.'));
    } finally {
      if (mounted) setState(() => _busyKey = null);
      await _reload();
    }
  }

  Future<void> _openAttention(AttentionWithProducts attention, {bool fromRoute = false}) async {
    final restaurant = _site.restaurant;

    if (restaurant == null) {
      return;
    }

    final result = await showAttentionDialog(
      context,
      attention: attention,
      source: _attentions,
      currency: _site.currency,
      timezone: restaurant.timezone,
      onChanged: _reload,
    );

    if (!mounted) return;

    // Nunca dos hojas apiladas: el detalle ya se cerró antes de abrir el pedido manual.
    if (result == addProductsResult) {
      final latest = _attentions.value.where((item) => item.id == attention.id).firstOrNull ?? attention;
      await _openStaffOrder(latest.tableNumber);
    }

    if (fromRoute && mounted) {
      context.go(Routes.siteOrders(widget.siteSlug));
    }
  }

  Future<void> _openStaffOrder(String? tableNumber) async {
    final restaurant = _site.restaurant;

    if (restaurant == null) {
      return;
    }

    final attentionId = await showStaffOrderDialog(context, restaurant: restaurant, presetTableNumber: tableNumber);

    if (attentionId != null && mounted) {
      context.read<ToastStore>().show('Pedido registrado', message: 'Los productos entraron directo a cocina.', tone: 'success');
      await _reload();
      unawaited(_activity.refresh());
    }
  }

  Future<void> _selectTicket(BoardCard ticket) async {
    final restaurant = _site.restaurant;

    if (restaurant == null) {
      return;
    }

    final result = await showOrderTicketDialog(
      context,
      ticket: ticket,
      currency: _site.currency,
      timezone: restaurant.timezone,
      now: _now,
      onAdvance: () async {
        final to = nextOrderedProductStatus(ticket.status);

        if (to != null) {
          await _advanceCard(AdvancePayload(key: ticket.key, tableNumber: ticket.attention.tableNumber, products: ticket.products, to: to));
        }
      },
    );

    if (result == openAttentionResult && mounted) {
      final latest = _attentions.value.where((item) => item.id == ticket.attention.id).firstOrNull ?? ticket.attention;
      await _openAttention(latest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = _site.restaurant;

    return RefreshIndicator(
      onRefresh: _reload,
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
              section: 'Gestión de pedidos',
              title: 'Gestión de pedidos',
              description: 'Sigue cada comanda desde que llega hasta que se entrega. En el tablero, avanza cada tarjeta al paso siguiente con su botón.',
              actions: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'board', label: Text('Tablero'), icon: Icon(Icons.view_kanban_outlined)),
                    ButtonSegment(value: 'list', label: Text('Lista'), icon: Icon(Icons.view_list_rounded)),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (value) => setState(() => _viewMode = value.first),
                ),
                BaseButton(label: '+ Pedido manual', variant: 'primary', onPressed: () => _openStaffOrder(null)),
              ],
            ),
            const SizedBox(height: 16),
            if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 16)],
            if (_viewMode == 'board')
              OrdersBoard(attentions: _attentions.value, now: _now, busyKey: _busyKey, onAdvance: _advanceCard, onSelect: _selectTicket)
            else
              ..._buildList(context),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildList(BuildContext context) {
    final c = context.colors;
    final incoming = _incomingRounds;
    final incomingCount = incoming.fold<int>(0, (sum, round) => sum + round.products.length);
    final visible = _showClosed ? _attentions.value : _attentions.value.where(isAttentionActive).toList();

    return [
      Row(
        children: [
          Text('Por confirmar', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
          if (incomingCount > 0) ...[const SizedBox(width: 8), Pill('$incomingCount', background: c.error, foreground: c.onError)],
        ],
      ),
      const SizedBox(height: 12),
      if (incoming.isEmpty)
        const EmptyState(
          icon: 'check',
          title: 'Todo confirmado',
          message: 'Cuando una mesa envíe un pedido aparecerá aquí, con aviso sonoro.',
        ),
      for (final round in incoming) ...[_roundCard(context, round), const SizedBox(height: 12)],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text('Atenciones', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
          ),
          FilterChip(
            selected: _showClosed,
            showCheckmark: false,
            label: Text(_showClosed ? 'Mostrando todas' : 'Mostrar cerradas'),
            onSelected: (value) => setState(() => _showClosed = value),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (final attention in visible) ...[
        AttentionCard(attention: attention, currency: _site.currency, onSelect: () => _openAttention(attention)),
        const SizedBox(height: 10),
      ],
      if (visible.isEmpty) Text('No hay atenciones para mostrar.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
    ];
  }

  Widget _roundCard(BuildContext context, _IncomingRound round) {
    final c = context.colors;
    final delay = _roundDelay(round);
    final label = delayLabel[delay] ?? '';

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      borderColor: delayRingColor(context, delay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => _openAttention(round.attention),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    widthFactor: 1,
                    child: Text(
                      'Mesa ${round.attention.tableNumber}',
                      style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700, color: c.onSurface),
                    ),
                  ),
                ),
              ),
              Pill('Ronda ${round.roundNumber}', background: c.surfaceContainer, foreground: c.onSurfaceVariant),
              Pill(
                round.createdBy != null ? 'Cargado por ${round.createdBy}' : 'QR',
                background: round.createdBy != null ? c.primaryFixed : c.secondaryContainer,
                foreground: round.createdBy != null ? c.onPrimaryFixed : c.onSecondaryContainer,
              ),
              Text(
                '${label.isNotEmpty ? '$label · ' : ''}${formatElapsed(round.requestedAt, _now)}',
                style: AppFonts.label(fontSize: 14, color: delayTextColor(context, delay)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final product in round.products) ...[_incomingProduct(context, product), const SizedBox(height: 8)],
          const SizedBox(height: 4),
          BaseButton(
            label: _busyKey == round.key ? 'Confirmando…' : 'Confirmar ronda (${round.products.length})',
            variant: 'primary',
            size: 'lg',
            block: true,
            disabled: _busyKey == round.key,
            onPressed: () => _confirmRound(round),
          ),
        ],
      ),
    );
  }

  Widget _incomingProduct(BuildContext context, OrderedProduct product) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
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
                    Text(
                      '${product.quantity}× ${product.name}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                    ),
                    if (product.notes.isNotEmpty)
                      Text(
                        'Nota: ${product.notes}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.tertiary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMoney(product.subtotal, _site.currency),
                style: tabular(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_rejectingId == product.id)
            ReasonBox(
              controller: _rejectionReason,
              hint: 'Motivo del rechazo (ej: agotado)',
              confirmLabel: 'Rechazar',
              busy: _busyKey == product.id,
              onCancel: () => setState(() => _rejectingId = null),
              onConfirm: () => _confirmReject(product),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BaseButton(label: 'Rechazar', variant: 'danger-soft', onPressed: () => _startReject(product)),
                const SizedBox(width: 8),
                BaseButton(label: 'Confirmar', disabled: _busyKey == product.id, onPressed: () => _confirmProduct(product)),
              ],
            ),
        ],
      ),
    );
  }
}
