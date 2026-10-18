import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../stores/session_store.dart';
import '../../../stores/site_activity_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/empty_state.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../rounds.dart';
import '../types.dart';
import '../widgets/service_ui.dart';

class _KitchenItem {
  const _KitchenItem({required this.product, required this.tableNumber, required this.since});

  final OrderedProduct product;
  final String tableNumber;

  /// Desde cuándo está en cocina (pasó a "en preparación"): mide la demora.
  final String since;
}

const String _darkKey = 'restaurant-cmr:kitchen-dark';

/// Cola de cocina: productos en preparación del más antiguo al más nuevo, con demora por color.
/// (Sección apagada por `Features.kitchenQueue`; el código se conserva.)
class KitchenQueueView extends StatefulWidget {
  const KitchenQueueView({super.key, required this.siteSlug});

  final String siteSlug;

  @override
  State<KitchenQueueView> createState() => _KitchenQueueViewState();
}

class _KitchenQueueViewState extends State<KitchenQueueView> {
  late final SiteContext _site;
  late final SiteActivityStore _activity;
  late int _lastRevision;

  List<_KitchenItem> _items = const [];
  String? _busyId;
  String? _actionError;
  bool _isFullscreen = false;
  bool _isDark = LocalStorage.getItem(_darkKey) == '1';
  int _now = nowMs();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadQueue)..addListener(_onSiteChanged);
    _activity = context.read<SiteActivityStore>();
    _lastRevision = _activity.revision;
    _activity.addListener(_onActivity);
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = nowMs());
    });
    unawaited(_site.load());
  }

  @override
  void didUpdateWidget(covariant KitchenQueueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteSlug != widget.siteSlug) unawaited(_site.setSlug(widget.siteSlug));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _activity.removeListener(_onActivity);
    _site.removeListener(_onSiteChanged);
    _site.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  void _onActivity() {
    if (_activity.revision != _lastRevision) {
      _lastRevision = _activity.revision;
      unawaited(_reload());
    }
  }

  String get _staffName => context.read<SessionStore>().user?.name ?? 'Cocina';

  Future<void> _loadQueue([RestaurantSite? site]) async {
    final id = site?.id ?? _site.restaurantId;

    if (id == null) {
      return;
    }

    final results = await Future.wait<Object>([fetchAttentionsWithProductsBySite(id), fetchAllStatusHistory()]);
    final attentions = results[0] as List<AttentionWithProducts>;
    final since = statusSinceMap(results[1] as List<StatusHistoryEntry>);
    final items = [
      for (final attention in attentions.where(isAttentionActive))
        for (final product in attention.products.where((product) => product.status == 'preparing'))
          _KitchenItem(product: product, tableNumber: attention.tableNumber, since: since[product.id] ?? product.requestedAt),
    ]..sort((a, b) => a.since.compareTo(b.since));

    if (mounted) setState(() => _items = items);
  }

  Future<void> _reload() async {
    try {
      await _loadQueue();
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo actualizar la cola.'));
    }
  }

  DelayLevel _itemDelay(_KitchenItem item) => delayLevel(minutesSince(item.since, _now), kitchenDelayMinutes);

  Future<void> _advance(_KitchenItem item) async {
    // Lo que llega a cocina ya está en preparación: el único paso aquí es marcarlo listo.
    setState(() {
      _busyId = item.product.id;
      _actionError = null;
    });
    final toast = context.read<ToastStore>();

    try {
      await updateOrderedProductStatus(item.product, 'ready', _staffName);
      toast.show('Mesa ${item.tableNumber}: ${item.product.name} listo', tone: 'success');
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo actualizar la comanda.'));

      if (error is! ConflictError) {
        if (mounted) setState(() => _busyId = null);
        return;
      }
    }

    if (mounted) setState(() => _busyId = null);
    await _reload();
    unawaited(_activity.refresh());
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    LocalStorage.setItem(_darkKey, _isDark ? '1' : '0');
  }

  /// En móvil "pantalla completa" oculta las barras del sistema (modo inmersivo).
  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    await SystemChrome.setEnabledSystemUIMode(next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) setState(() => _isFullscreen = next);
  }

  @override
  Widget build(BuildContext context) {
    final content = Builder(builder: _buildContent);
    return _isDark ? Theme(data: AppTheme.dark(), child: content) : content;
  }

  Widget _buildContent(BuildContext context) {
    final c = context.colors;
    final restaurant = _site.restaurant;
    final criticalCount = _items.where((item) => _itemDelay(item) == 'critical').length;

    return ColoredBox(
      color: c.background,
      child: RefreshIndicator(
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
                section: 'Cocina',
                title: 'Cola de cocina',
                description:
                    'Del más antiguo al más nuevo. Ámbar a partir de $kitchenDelayMinutes min, rojo a partir de ${kitchenDelayMinutes * 2} min.',
                actions: [
                  if (criticalCount > 0)
                    Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                      child: Center(
                        widthFactor: 1,
                        child: Text('$criticalCount muy demorado(s)', style: AppFonts.label(fontSize: 14, color: c.onErrorContainer)),
                      ),
                    ),
                  BaseButton(label: _isDark ? 'Tema claro' : 'Tema oscuro', onPressed: _toggleDark),
                  BaseButton(label: _isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa', onPressed: _toggleFullscreen),
                ],
              ),
              const SizedBox(height: 16),
              if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 16)],
              Row(
                children: [
                  Text('En preparación', style: AppFonts.headline(fontSize: 22, color: c.onSurface)),
                  const SizedBox(width: 8),
                  Pill('${_items.length}', background: c.primaryFixed, foreground: c.onPrimaryFixed),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const EmptyState(icon: 'fire', title: 'Nada en el fuego', message: 'Cuando la sala confirme un pedido aparecerá aquí.'),
              for (final item in _items) ...[_itemCard(context, item), const SizedBox(height: 12)],
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemCard(BuildContext context, _KitchenItem item) {
    final c = context.colors;
    final delay = _itemDelay(item);
    final label = delayLabel[delay] ?? '';

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      borderColor: delayRingColor(context, delay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mesa ${item.tableNumber}',
                  style: AppFonts.headline(fontSize: 26, fontWeight: FontWeight.w700, color: c.onSurface),
                ),
              ),
              Text(
                '${label.isNotEmpty ? '$label · ' : ''}${formatElapsed(item.since, _now)}',
                style: AppFonts.label(fontSize: 15, color: delayTextColor(context, delay)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w600, color: c.onSurface),
              children: [
                TextSpan(
                  text: '${item.product.quantity}× ',
                  style: TextStyle(color: c.primary),
                ),
                TextSpan(text: item.product.name),
              ],
            ),
          ),
          if (item.product.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '⚠ ${item.product.notes}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.onWarningContainer),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: BaseButton(
              label: 'Marcar listo',
              variant: 'success',
              size: 'lg',
              block: true,
              disabled: _busyId == item.product.id,
              onPressed: () => _advance(item),
            ),
          ),
        ],
      ),
    );
  }
}
