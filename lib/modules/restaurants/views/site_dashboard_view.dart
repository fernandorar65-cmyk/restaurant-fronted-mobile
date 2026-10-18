import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/http/http_client.dart';
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
import '../../../widgets/base/base_dialog.dart';
import '../../../widgets/base/kpi_tile.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../orders/api.dart';
import '../../orders/order_status_labels.dart';
import '../../orders/types.dart';
import '../../orders/widgets/staff_order_dialog.dart';
import '../api.dart';
import '../site_labels.dart';
import '../types.dart';
import '../widgets/floors_dialog.dart';
import '../widgets/site_floor_table.dart';
import '../widgets/site_table_card.dart';
import '../widgets/table_form_dialog.dart';

/// Origen público del front web del comensal: los QR de mesa apuntan a `<origen>/table/...`.
/// En la web es `window.location.origin`; en la app se fija al compilar con
/// `--dart-define=PUBLIC_WEB_URL=https://mi-dominio`.
const String _publicWebOrigin = AppConfig.publicWebUrl;

const List<(String, String)> _floorFilters = [
  ('all', 'Todas'),
  ('occupied', 'Ocupada'),
  ('available', 'Libre'),
  ('reserved', 'Reservada'),
  ('cleaning', 'Limpieza'),
];

class _TableGroup {
  const _TableGroup(this.id, this.name, this.tables);

  final String id;
  final String? name;
  final List<LiveTable> tables;
}

/// Gestión de mesas de una sede: plano, estado de las mesas, QR y atenciones abiertas.
class SiteDashboardView extends StatefulWidget {
  const SiteDashboardView({super.key, required this.siteSlug});

  final String siteSlug;

  @override
  State<SiteDashboardView> createState() => _SiteDashboardViewState();
}

class _SiteDashboardViewState extends State<SiteDashboardView> {
  late final SiteActivityStore _activity = context.read<SiteActivityStore>();
  late final SiteContext _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadSite);
  late int _lastRevision = _activity.revision;

  SiteOperation? _operation;
  List<AttentionWithProducts> _attentions = const [];
  String _floorFilter = 'all';

  /// Piso que se está viendo; 'all' = todos (agrupados por piso).
  String _activeFloor = 'all';
  String? _selectedTableNumber;
  String? _tableActionError;
  final GlobalKey _detailKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _site.addListener(_onSiteChanged);
    _activity.addListener(_onActivity);
    unawaited(_site.load());
  }

  @override
  void didUpdateWidget(covariant SiteDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteSlug != widget.siteSlug) unawaited(_site.setSlug(widget.siteSlug));
  }

  @override
  void dispose() {
    _site.removeListener(_onSiteChanged);
    _activity.removeListener(_onActivity);
    _site.dispose();
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  void _onActivity() {
    if (_activity.revision == _lastRevision) return;
    _lastRevision = _activity.revision;
    unawaited(_refreshAttentions());
  }

  Future<void> _loadSite(RestaurantSite site) async {
    _operation = null;
    _selectedTableNumber = null;
    _tableActionError = null;

    final results = await Future.wait<Object?>([fetchSiteOperation(site.id), fetchAttentionsWithProductsBySite(site.id)]);
    final operation = results[0] as SiteOperation?;
    _attentions = results[1]! as List<AttentionWithProducts>;
    _operation = operation;

    if (operation == null) {
      throw HttpError('No hay datos operativos para esta sede.', 404);
    }

    _syncActiveFloor();
    final firstOccupied = _liveTables.where((table) => table.floorStatus == 'occupied').firstOrNull;
    _selectedTableNumber = firstOccupied?.number ?? operation.tables.firstOrNull?.number;
  }

  Future<void> _refreshAttentions() async {
    final id = _site.restaurantId;
    if (id == null) return;

    try {
      final attentions = await fetchAttentionsWithProductsBySite(id);
      if (mounted) setState(() => _attentions = attentions);
    } catch (_) {
      // Se reintenta en el próximo ciclo de actividad.
    }
  }

  // ── Derivados ──────────────────────────────────────────

  String get _currency => _site.currency;

  Map<String, AttentionWithProducts> get _activeAttentionByTable => {
        for (final attention in _attentions.where(isAttentionActive)) attention.tableNumber: attention,
      };

  /// Mesas con el estado de sala calculado a partir de las atenciones reales:
  /// ocupada si tiene una atención activa; si no, se respeta reservada/limpieza.
  List<LiveTable> get _liveTables {
    final byTable = _activeAttentionByTable;

    return (_operation?.tables ?? const <LiveTable>[]).map((table) {
      if (byTable.containsKey(table.number)) {
        return table.copyWith(
          floorStatus: 'occupied',
          occupiedSeats: table.occupiedSeats > 0 ? table.occupiedSeats : (table.seats < 2 ? table.seats : 2),
        );
      }

      return table.floorStatus == 'occupied' ? table.copyWith(floorStatus: 'available', occupiedSeats: 0) : table;
    }).toList();
  }

  List<SiteFloor> get _floors => _operation?.floors ?? const [];

  bool get _hasFloors => _floors.length > 1;

  /// Si el piso elegido deja de existir (o la sede queda con uno solo), se vuelve a "Todos".
  void _syncActiveFloor() {
    if (_activeFloor != 'all' && !_floors.any((floor) => floor.id == _activeFloor)) _activeFloor = 'all';
  }

  void _setOperation(SiteOperation operation) {
    _operation = operation;
    _syncActiveFloor();
  }

  String _tableUrl(LiveTable table) =>
      '$_publicWebOrigin/table/${Uri.encodeComponent(table.number)}?restaurant=${_site.restaurantId}&token=${table.qrToken}';

  // ── Acciones ───────────────────────────────────────────

  void _selectTable(String number) {
    setState(() => _selectedTableNumber = number);

    // El detalle queda debajo del plano: se lleva a la vista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final detail = _detailKey.currentContext;
      if (detail != null && detail.mounted) {
        Scrollable.ensureVisible(detail, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _copyTableLink(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) context.read<ToastStore>().show('Enlace copiado', tone: 'success', durationMs: 2500);
    } catch (_) {
      setState(() => _tableActionError = 'No se pudo copiar el enlace.');
    }
  }

  Future<String?> _saveTable(LiveTable? original, LiveTable table) async {
    final operation = _operation;
    if (operation == null) return null;

    setState(() => _tableActionError = null);

    if (original != null && original.number != table.number && _activeAttentionByTable.containsKey(original.number)) {
      setState(() => _tableActionError = 'No se puede renumerar la mesa ${original.number}: tiene una atención abierta.');
      return null;
    }

    final tables = original != null
        ? operation.tables.map((item) => item.number == original.number ? table : item).toList()
        : [...operation.tables, table];

    try {
      final updated = await updateSiteOperationTables(operation.id, tables);
      if (mounted) {
        setState(() {
          _setOperation(updated);
          _selectedTableNumber = table.number;
        });
      }
      return null;
    } catch (_) {
      final message = original != null ? 'No se pudo guardar la mesa.' : 'No se pudo crear la mesa.';
      if (mounted) setState(() => _tableActionError = message);
      return message;
    }
  }

  void _openTableForm(LiveTable? table) {
    final operation = _operation;
    if (operation == null) return;

    unawaited(TableFormDialog.show(
      context,
      table: table,
      existingNumbers: operation.tables.map((item) => item.number).toList(),
      floors: _floors,
      defaultFloorId: _activeFloor == 'all' ? null : _activeFloor,
      onSave: (saved) => _saveTable(table, saved),
    ));
  }

  /// Mueve una mesa a otro piso (desde el selector del detalle).
  Future<void> _moveTable(String tableNumber, String floorId) async {
    final operation = _operation;
    final table = operation?.tables.where((item) => item.number == tableNumber).firstOrNull;

    if (operation == null || table == null || table.floorId == floorId) return;

    setState(() => _tableActionError = null);

    try {
      final updated = await updateSiteOperationTables(
        operation.id,
        operation.tables.map((item) => item.number == tableNumber ? item.copyWith(floorId: floorId) : item).toList(),
      );
      if (!mounted) return;
      setState(() => _setOperation(updated));
      final floorName = _floors.where((floor) => floor.id == floorId).firstOrNull?.name ?? 'otro piso';
      context.read<ToastStore>().show('Mesa $tableNumber movida a $floorName', tone: 'success');
    } catch (_) {
      if (mounted) setState(() => _tableActionError = 'No se pudo mover la mesa de piso.');
    }
  }

  Future<String?> _saveFloors(List<SiteFloor> floors, List<LiveTable> tables) async {
    final operation = _operation;
    if (operation == null) return null;

    setState(() => _tableActionError = null);

    try {
      final updated = await updateSiteOperationFloors(operation.id, floors, tables);
      if (mounted) setState(() => _setOperation(updated));
      return null;
    } catch (_) {
      const message = 'No se pudieron guardar los pisos.';
      if (mounted) setState(() => _tableActionError = message);
      return message;
    }
  }

  Future<void> _updateSelected(LiveTable Function(LiveTable item) change, String errorMessage) async {
    final operation = _operation;
    final table = _selectedTable;
    if (operation == null || table == null) return;

    setState(() => _tableActionError = null);

    try {
      final updated = await updateSiteOperationTables(
        operation.id,
        operation.tables.map((item) => item.number == table.number ? change(item) : item).toList(),
      );
      if (mounted) setState(() => _setOperation(updated));
    } catch (_) {
      if (mounted) setState(() => _tableActionError = errorMessage);
    }
  }

  Future<void> _toggleTableQr() => _updateSelected((item) => item.copyWith(qrActive: !item.qrActive), 'No se pudo actualizar el QR.');

  Future<void> _regenerateTableQr() {
    final token = createQrToken();
    return _updateSelected((item) => item.copyWith(qrToken: token), 'No se pudo regenerar el QR.');
  }

  Future<void> _removeSelectedTable() async {
    final operation = _operation;
    final table = _selectedTable;
    if (operation == null || table == null) return;

    if (_activeAttentionByTable.containsKey(table.number)) {
      setState(() => _tableActionError = 'La mesa ${table.number} tiene una atención abierta: ciérrala antes de eliminarla.');
      return;
    }

    final accepted = await confirmAction(
      context,
      title: '¿Eliminar la mesa ${table.number}?',
      message: 'Su código QR dejará de funcionar. Si es algo temporal, ponla en mantenimiento.',
      confirmLabel: 'Eliminar mesa',
      tone: 'danger',
    );

    if (!accepted || !mounted) return;

    setState(() => _tableActionError = null);

    try {
      final updated = await updateSiteOperationTables(
        operation.id,
        operation.tables.where((item) => item.number != table.number).toList(),
      );
      if (!mounted) return;
      setState(() {
        _setOperation(updated);
        _selectedTableNumber = updated.tables.firstOrNull?.number;
      });
    } catch (_) {
      if (mounted) setState(() => _tableActionError = 'No se pudo eliminar la mesa.');
    }
  }

  /// En la web abre una hoja imprimible; en la app muestra los QR de las mesas activas
  /// en una hoja para escanearlos o copiar sus enlaces.
  void _showAllQrs() {
    final site = _site.restaurant;
    final tables = _liveTables.where((table) => table.status == 'active' && table.qrActive).toList();

    if (site == null || tables.isEmpty) {
      setState(() => _tableActionError = 'No hay mesas activas con QR habilitado para imprimir.');
      return;
    }

    unawaited(showBaseDialog<void>(
      context,
      title: 'QR de mesas',
      subtitle: site.name,
      builder: (sheetContext) {
        final c = sheetContext.colors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final table in tables)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.outlineVariant),
                ),
                child: Column(
                  children: [
                    _QrBox(data: _tableUrl(table), size: 200, label: 'QR de la mesa ${table.number}'),
                    const SizedBox(height: 8),
                    Text('Mesa ${table.number}', style: AppFonts.headline(fontSize: 22, color: c.onSurface)),
                    Text(site.name, style: TextStyle(color: c.onSurfaceVariant)),
                    Text('Escanea para ver la carta y pedir', style: TextStyle(fontSize: 12, color: c.outline)),
                    const SizedBox(height: 8),
                    BaseButton(
                      label: 'Copiar enlace',
                      size: 'sm',
                      icon: Icons.copy_rounded,
                      onPressed: () => _copyTableLink(_tableUrl(table)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ));
  }

  void _showQrLarge(LiveTable table, String url) {
    unawaited(showBaseDialog<void>(
      context,
      title: 'Mesa ${table.number}',
      subtitle: 'Escanea para ver la carta y pedir',
      builder: (sheetContext) => Column(
        children: [
          _QrBox(data: url, size: 260, label: 'QR de la mesa ${table.number}'),
          const SizedBox(height: 12),
          SelectableText(url, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: sheetContext.colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          BaseButton(label: 'Copiar enlace', icon: Icons.copy_rounded, onPressed: () => _copyTableLink(url)),
        ],
      ),
    ));
  }

  Future<void> _openManualOrder(RestaurantSite site, String tableNumber) async {
    final created = await showStaffOrderDialog(context, restaurant: site, presetTableNumber: tableNumber);
    if (created != null) await _refreshAttentions();
  }

  LiveTable? get _selectedTable => _liveTables.where((table) => table.number == _selectedTableNumber).firstOrNull;

  // ── UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final site = _site.restaurant;
    final operation = _operation;

    Widget body;

    if (_site.isLoading) {
      body = const SkeletonBlock(variant: 'page');
    } else if (_site.loadError != null) {
      body = _ErrorBox(message: _site.loadError!);
    } else if (site != null && operation != null) {
      body = _buildContent(context, session, site, operation);
    } else {
      body = const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _site.reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [body],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SessionStore session, RestaurantSite site, SiteOperation operation) {
    final c = context.colors;
    final tables = _liveTables;
    final byTable = _activeAttentionByTable;

    // Indicadores de mesas
    final tablesOccupied = tables.where((table) => table.floorStatus == 'occupied').length;
    final tablesAvailable = tables.where((table) => table.floorStatus == 'available').length;
    final tablesBlocked = tables.where((table) => table.status != 'active').length;
    final seatsTotal = tables.fold<int>(0, (sum, table) => sum + table.seats);
    final seatsOccupied = tables.fold<int>(0, (sum, table) => sum + table.occupiedSeats);
    final seatPercent = seatsTotal == 0 ? 0 : (seatsOccupied / seatsTotal * 100).round();

    // Indicadores de servicio
    final active = _attentions.where(isAttentionActive).toList();
    final activeProducts = active.expand((attention) => attention.products).toList();
    final accountRequested = active.where((attention) => attention.status == 'account-requested').length;
    final inKitchen = activeProducts.where((product) => product.status == 'preparing').length;
    final openTotal = activeProducts.where((product) => isBillableProduct(product.status)).fold<double>(0, (sum, p) => sum + p.subtotal);

    final visibleTables = tables
        .where((table) =>
            (_activeFloor == 'all' || table.floorId == _activeFloor) && (_floorFilter == 'all' || table.floorStatus == _floorFilter))
        .toList();
    int floorCount(String id) => tables.where((table) => table.floorId == id).length;

    // Con varios pisos y "Todos", las mesas se agrupan por piso; si no, un solo grupo.
    final groups = !_hasFloors || _activeFloor != 'all'
        ? [_TableGroup(_activeFloor, null, visibleTables)]
        : _floors
            .map((floor) => _TableGroup(floor.id, floor.name, visibleTables.where((table) => table.floorId == floor.id).toList()))
            .where((group) => group.tables.isNotEmpty)
            .toList();

    final selected = _selectedTable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SitePageHeader(
          restaurant: site,
          section: 'Gestión de mesas',
          title: 'Gestión de mesas',
          description: 'Plano, estado de las mesas, códigos QR y atenciones abiertas. La ocupación se calcula con los pedidos reales.',
          actions: [
            if (session.can('orders.manage'))
              BaseButton(label: 'Ir a gestión de pedidos', variant: 'primary', onPressed: () => context.go(Routes.siteOrders(site.slug))),
          ],
        ),
        const SizedBox(height: 16),
        _KpiGrid(children: [
          KpiTile(
            label: 'Mesas ocupadas',
            value: '$tablesOccupied / ${tables.length}',
            hint: '$tablesAvailable libres${tablesBlocked > 0 ? ' · $tablesBlocked fuera de servicio' : ''}',
          ),
          KpiTile(
            label: 'Cubiertos',
            value: '$seatPercent%',
            hint: '$seatsOccupied de $seatsTotal sillas',
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: seatPercent / 100,
                  minHeight: 8,
                  backgroundColor: c.surfaceContainerHigh,
                  color: c.primary,
                ),
              ),
            ),
          ),
          KpiTile(
            label: 'Atenciones abiertas',
            value: '${active.length}',
            hint: '$inKitchen en preparación · $accountRequested piden cuenta',
          ),
          KpiTile(label: 'Por cobrar', value: formatMoney(openTotal, _currency), hint: 'Total de las atenciones abiertas'),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Plano de sala', style: AppFonts.headline(fontSize: 20, color: c.onSurface)),
              const SizedBox(height: 4),
              Text(
                'Cada punto es una silla. Toca una mesa para ver su atención y su QR.'
                '${_hasFloors ? ' Cambia el piso de una mesa desde su detalle.' : ''}',
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BaseButton(
                    label: 'Pisos${_hasFloors ? ' (${_floors.length})' : ''}',
                    size: 'sm',
                    icon: Icons.layers_outlined,
                    onPressed: () => FloorsDialog.show(context, floors: _floors, tables: operation.tables, onSave: _saveFloors),
                  ),
                  BaseButton(label: 'QR de mesas', size: 'sm', icon: Icons.qr_code_2_rounded, onPressed: _showAllQrs),
                  BaseButton(label: '+ Mesa', size: 'sm', variant: 'primary', onPressed: () => _openTableForm(null)),
                ],
              ),
              const SizedBox(height: 12),

              // Pestañas de piso: solo si la sede tiene más de uno
              if (_hasFloors) ...[
                _ChipRow(
                  label: 'Pisos',
                  children: [
                    for (final tab in [('all', 'Todos', tables.length), for (final floor in _floors) (floor.id, floor.name, floorCount(floor.id))])
                      ChoiceChip(
                        label: Text('${tab.$2}  ${tab.$3}'),
                        selected: _activeFloor == tab.$1,
                        onSelected: (_) => setState(() => _activeFloor = tab.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _ChipRow(
                label: 'Filtrar mesas por estado',
                children: [
                  for (final filter in _floorFilters)
                    ChoiceChip(
                      label: Text(filter.$2),
                      selected: _floorFilter == filter.$1,
                      onSelected: (_) => setState(() => _floorFilter = filter.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final group in groups) ...[
                if (group.name != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        Text(group.name!.toUpperCase(), style: AppFonts.label(fontSize: 12, color: c.onSurfaceVariant, letterSpacing: 1)),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: c.outlineVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 112).floor().clamp(3, 10);
                  final width = constraints.maxWidth / columns;

                  return Wrap(
                    children: [
                      for (final table in group.tables)
                        SizedBox(
                          width: width,
                          child: Center(
                            child: SiteFloorTable(
                              table: table,
                              selected: table.number == _selectedTableNumber,
                              onSelect: () => _selectTable(table.number),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
              ],
              if (visibleTables.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tables.isEmpty
                        ? 'Esta sede todavía no tiene mesas. Usa "+ Mesa" para agregar la primera.'
                        : _activeFloor != 'all' && floorCount(_activeFloor) == 0
                            ? 'Este piso todavía no tiene mesas. Usa "+ Mesa" para agregar una.'
                            : 'No hay mesas en este estado.',
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                  ),
                ),
              if (selected != null) _buildDetail(context, session, site, selected, byTable[selected.number]),
              if (_tableActionError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_tableActionError!, style: TextStyle(fontSize: 13, color: c.error)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetail(BuildContext context, SessionStore session, RestaurantSite site, LiveTable table, AttentionWithProducts? attention) {
    final c = context.colors;
    final url = _tableUrl(table);
    final attentionTotal =
        (attention?.products ?? const <OrderedProduct>[]).where((product) => isBillableProduct(product.status)).fold<double>(0, (sum, p) => sum + p.subtotal);
    final isActive = table.status == 'active';

    Widget panel({required List<Widget> children}) => Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    Widget statusChip(String label, bool ok) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: ok ? c.primary.withValues(alpha: 0.1) : c.errorContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: AppFonts.label(fontSize: 12, color: ok ? c.primary : c.onErrorContainer)),
        );

    return Container(
      key: _detailKey,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('MESA SELECCIONADA · ${table.code}', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
                  statusChip(tableStatusLabel[table.status] ?? table.status, isActive),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BaseButton(label: 'Editar', size: 'sm', onPressed: () => _openTableForm(_operation?.tables.where((item) => item.number == table.number).firstOrNull)),
                  const SizedBox(width: 6),
                  BaseButton(label: 'Eliminar', size: 'sm', variant: 'danger-soft', onPressed: _removeSelectedTable),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SiteTableCard(table: table, highlight: true),
          if (_hasFloors) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('floor-${table.number}-${table.floorId}'),
              initialValue: _floors.any((floor) => floor.id == table.floorId) ? table.floorId : null,
              decoration: const InputDecoration(labelText: 'Piso', helperText: 'Cámbialo para mover la mesa de piso.'),
              items: [for (final floor in _floors) DropdownMenuItem(value: floor.id, child: Text(floor.name))],
              onChanged: (value) {
                if (value != null) unawaited(_moveTable(table.number, value));
              },
            ),
          ],
          panel(children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('ATENCIÓN ACTIVA', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
                if (session.can('orders.manage') && isActive)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (attention != null) ...[
                        BaseButton(label: 'Ver detalle', size: 'sm', onPressed: () => context.push(Routes.siteOrderDetail(site.slug, attention.id))),
                        const SizedBox(width: 6),
                      ],
                      BaseButton(label: '+ Pedido manual', size: 'sm', variant: 'primary', onPressed: () => _openManualOrder(site, table.number)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (attention != null) ...[
              Text(
                'Abierta a las ${formatTime(attention.openedAt, site.timezone)} · ${formatMoney(attentionTotal, _currency)}',
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              for (final product in attention.products)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text('${product.quantity}× ${product.name}', style: TextStyle(fontSize: 13, color: c.onSurface))),
                      StatusBadge(
                        tone: orderedProductStatusTone[product.status] ?? 'neutral',
                        label: orderedProductStatusLabel[product.status] ?? product.status,
                      ),
                    ],
                  ),
                ),
            ] else
              Text('Sin atención abierta.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          ]),
          panel(children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: 'Ver QR en grande',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showQrLarge(table, url),
                    child: _QrBox(data: url, size: 96, label: 'QR de la mesa ${table.number}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ENLACE DE LA MESA (QR DE ACCESO AL MENÚ)', style: AppFonts.eyebrow(color: c.onSurfaceVariant, fontSize: 10)),
                      const SizedBox(height: 4),
                      statusChip(table.qrActive ? 'QR ACTIVO' : 'QR DESACTIVADO', table.qrActive),
                      const SizedBox(height: 4),
                      Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BaseButton(label: 'Copiar enlace', size: 'sm', icon: Icons.copy_rounded, onPressed: () => _copyTableLink(url)),
                BaseButton(label: table.qrActive ? 'Desactivar QR' : 'Activar QR', size: 'sm', onPressed: _toggleTableQr),
                BaseButton(label: 'Regenerar QR', size: 'sm', onPressed: _regenerateTableQr),
                if (table.qrActive)
                  BaseButton(
                    label: 'Abrir como comensal',
                    size: 'sm',
                    trailingIcon: Icons.north_east_rounded,
                    onPressed: () => context.push(Uri(
                      path: Routes.tableEntry(table.number),
                      queryParameters: {'restaurant': _site.restaurantId ?? '', 'token': table.qrToken},
                    ).toString()),
                  ),
              ],
            ),
          ]),
        ],
      ),
    );
  }
}

/// QR sobre fondo blanco (se lee igual en tema oscuro).
class _QrBox extends StatelessWidget {
  const _QrBox({required this.data, required this.size, required this.label});

  final String data;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: QrImageView(data: data, size: size, padding: EdgeInsets.zero, backgroundColor: Colors.white),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 4 : 2;
      const spacing = 12.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final child in children) Padding(padding: const EdgeInsets.only(right: 6), child: child),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.errorContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.errorContainer),
        ),
        child: Text(message, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
      ),
    );
  }
}
