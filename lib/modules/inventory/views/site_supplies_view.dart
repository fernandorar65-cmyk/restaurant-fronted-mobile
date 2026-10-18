import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/string.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_pagination.dart';
import '../../../widgets/base/kpi_tile.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../administration/admin_labels.dart';
import '../../orders/api.dart' show errorMessage;
import '../../restaurants/types.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/movement_dialog.dart';
import '../widgets/supply_dialog.dart';

/// Inventario de insumos de una sede: stock (por defecto) y movimientos (`?vista=movimientos`,
/// con `&insumo=id` para ver el historial de uno).
class SiteSuppliesView extends StatefulWidget {
  const SiteSuppliesView({super.key, required this.siteSlug, this.view});

  final String siteSlug;
  final String? view;

  @override
  State<SiteSuppliesView> createState() => _SiteSuppliesViewState();
}

class _SiteSuppliesViewState extends State<SiteSuppliesView> {
  late final SiteContext _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _load);

  List<Supply> _supplies = const [];
  List<StockMovement> _movements = const [];

  // Stock
  final TextEditingController _search = TextEditingController();
  String _categoryFilter = 'all';

  /// 'all' | 'restock' | 'inactive'
  String _statusFilter = 'all';
  int _stockPage = 1;
  int _stockPageSize = 15;

  // Movimientos
  String _typeFilter = 'all';
  int _movementPage = 1;
  int _movementPageSize = 15;
  String? _lastItemFilter;

  @override
  void initState() {
    super.initState();
    _site.addListener(_onSiteChanged);
    unawaited(_site.load());
  }

  @override
  void didUpdateWidget(covariant SiteSuppliesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteSlug != widget.siteSlug) unawaited(_site.setSlug(widget.siteSlug));
  }

  @override
  void dispose() {
    _site.removeListener(_onSiteChanged);
    _site.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load(RestaurantSite site) async {
    final results = await Future.wait<Object>([fetchSupplies(site.id), fetchMovements(site.id)]);
    _supplies = results[0] as List<Supply>;
    _movements = results[1] as List<StockMovement>;
  }

  String get _tab => widget.view == 'movimientos' ? 'movimientos' : 'stock';

  void _selectTab(String next, [String? itemId]) {
    final query = <String, String>{
      if (next == 'movimientos') 'vista': 'movimientos',
      'insumo': ?itemId,
    };
    context.go(Uri(path: Routes.siteSupplies(widget.siteSlug), queryParameters: query.isEmpty ? null : query).toString());
  }

  String _formatDateTime(String iso) =>
      DateFormat('d MMM, HH:mm', 'es').format(inZone(parseIso(iso), _site.restaurant?.timezone));

  // ── Diálogos ───────────────────────────────────────────

  void _openSupplyDialog(Supply? item) {
    unawaited(SupplyDialog.show(context, item: item, currency: _site.currency, onSave: (draft) => _saveSupply(item, draft)));
  }

  Future<bool> _saveSupply(Supply? current, SupplyDraft draft) async {
    final restaurantId = _site.restaurantId;
    if (restaurantId == null) return false;
    final toast = context.read<ToastStore>();

    try {
      final saved = current != null ? await updateSupply(current, draft) : await createSupply(restaurantId, draft);
      if (mounted) {
        setState(() {
          _supplies = current != null ? _supplies.map((item) => item.id == saved.id ? saved : item).toList() : [..._supplies, saved];
        });
      }
      toast.show(current != null ? 'Insumo actualizado' : 'Insumo creado', message: saved.name, tone: 'success', durationMs: 3000);
      return true;
    } catch (error) {
      toast.show('No se pudo guardar el insumo', message: errorMessage(error, 'Inténtalo de nuevo.'), tone: 'error');
      return false;
    }
  }

  void _openMovementDialog(Supply item, MovementType type) {
    unawaited(MovementDialog.show(
      context,
      item: item,
      initialType: type,
      currency: _site.currency,
      canRegisterExpense: context.read<SessionStore>().can('payments.manage'),
      onSave: (draft) => _saveMovement(item, draft),
    ));
  }

  Future<bool> _saveMovement(Supply supply, MovementDraft draft) async {
    final toast = context.read<ToastStore>();
    final session = context.read<SessionStore>();

    try {
      final result = await registerMovement(supply, draft, session.user?.name);
      final item = result.item;
      final movement = result.movement;
      if (mounted) {
        setState(() {
          _supplies = _supplies.map((current) => current.id == item.id ? item : current).toList();
          _movements = [movement, ..._movements];
        });
      }
      toast.show(
        '${movementTypeLabel[movement.type]} ${movement.type == 'count' ? 'registrado' : 'registrada'}',
        message: '${item.name}: ${formatQuantity(item.stock)} ${item.unit}${movement.expenseId != null ? ' · también en Gastos' : ''}',
        tone: item.status == 'ok' ? 'success' : 'warning',
        durationMs: 4000,
      );
      return true;
    } catch (error) {
      toast.show('No se pudo registrar el movimiento', message: errorMessage(error, 'Inténtalo de nuevo.'), tone: 'error');
      return false;
    }
  }

  // ── UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final site = _site.restaurant;
    Widget body;

    if (_site.isLoading) {
      body = const SkeletonBlock(variant: 'page');
    } else if (_site.loadError != null) {
      body = _Notice(message: _site.loadError!);
    } else if (site != null) {
      body = _buildContent(context, site);
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

  Widget _buildContent(BuildContext context, RestaurantSite site) {
    final currency = _site.currency;
    final active = _supplies.where((item) => item.isActive).toList();
    final toRestock = active.where((item) => item.status != 'ok').toList();
    final outOfStock = active.where((item) => item.stock <= 0).toList();
    final inventoryValue = active.fold<double>(0, (sum, item) => sum + item.stock * item.unitCost);

    // Resumen del mes en curso: compras y mermas valorizadas.
    final monthKey = DateTime.now().toUtc().toIso8601String().substring(0, 7);
    final monthMovements = _movements.where((movement) => movement.createdAt.startsWith(monthKey)).toList();
    final monthPurchases =
        monthMovements.where((m) => m.type == 'purchase').fold<double>(0, (sum, m) => sum + m.delta * (m.unitCost ?? 0));
    final monthWaste = monthMovements.where((m) => m.type == 'waste').fold<double>(
          0,
          (sum, m) => sum + m.delta.abs() * (_supplies.where((item) => item.id == m.itemId).firstOrNull?.unitCost ?? 0),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SitePageHeader(
          restaurant: site,
          section: 'Insumos',
          title: 'Inventario de insumos',
          description:
              'Controla el stock de la despensa: registra compras, consumos, mermas y conteos, y repón antes de quedarte sin nada.',
          actions: [BaseButton(label: '+ Nuevo insumo', variant: 'primary', onPressed: () => _openSupplyDialog(null))],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final tile in [
                KpiTile(label: 'Insumos activos', value: '${active.length}'),
                KpiTile(
                  label: 'Por reponer',
                  value: '${toRestock.length}',
                  tone: toRestock.isNotEmpty ? 'warning' : 'default',
                  hint: toRestock.isEmpty
                      ? 'Todo sobre el mínimo'
                      : outOfStock.isNotEmpty
                          ? '${outOfStock.length} agotados'
                          : 'Bajo el stock mínimo',
                ),
                KpiTile(label: 'Valor del inventario', value: formatMoney(inventoryValue, currency), hint: 'Stock × último costo'),
                KpiTile(
                  label: 'Compras del mes',
                  value: formatMoney(monthPurchases, currency),
                  hint: 'Mermas: ${formatMoney(monthWaste, currency)}',
                ),
              ])
                SizedBox(width: width, child: tile),
            ],
          );
        }),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'stock', label: Text('Stock')),
              ButtonSegment(value: 'movimientos', label: Text('Movimientos')),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => _selectTab(selection.first),
          ),
        ),
        const SizedBox(height: 16),
        if (_tab == 'stock') _buildStock(context, toRestock.length) else _buildMovements(context),
      ],
    );
  }

  Widget _buildStock(BuildContext context, int restockCount) {
    final currency = _site.currency;
    final term = normalizeSearch(_search.text);
    int rank(Supply item) => item.status == 'critical' ? 0 : item.status == 'low' ? 1 : 2;

    final filtered = _supplies
        .where((item) => _statusFilter == 'inactive' ? !item.isActive : item.isActive)
        .where((item) => _statusFilter != 'restock' || item.status != 'ok')
        .where((item) => _categoryFilter == 'all' || item.category == _categoryFilter)
        .where((item) => term.isEmpty || normalizeSearch('${item.name} ${item.supplier}').contains(term))
        .toList()
      // Primero lo que hay que reponer
      ..sort((a, b) {
        final byRank = rank(a) - rank(b);
        return byRank != 0 ? byRank : normalizeSearch(a.name).compareTo(normalizeSearch(b.name));
      });
    final pageCount = max(1, (filtered.length / _stockPageSize).ceil());
    final page = min(_stockPage, pageCount);
    final rows = filtered.skip((page - 1) * _stockPageSize).take(_stockPageSize).toList();

    void setFilter(VoidCallback change) => setState(() {
          change();
          _stockPage = 1;
        });

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setFilter(() {}),
          decoration: const InputDecoration(hintText: 'Buscar insumo o proveedor', prefixIcon: Icon(Icons.search_rounded), isDense: true),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _categoryFilter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('Todas las categorías')),
            for (final category in supplyCategories) DropdownMenuItem(value: category, child: Text(supplyCategoryLabel[category] ?? category)),
          ],
          onChanged: (value) => setFilter(() => _categoryFilter = value ?? 'all'),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('Todos', _statusFilter == 'all', () => setFilter(() => _statusFilter = 'all')),
              chip('Por reponer ($restockCount)', _statusFilter == 'restock', () => setFilter(() => _statusFilter = 'restock')),
              chip('Inactivos', _statusFilter == 'inactive', () => setFilter(() => _statusFilter = 'inactive')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _EmptyCard(
            message: _supplies.isEmpty ? 'Todavía no hay insumos. Crea el primero con «+ Nuevo insumo».' : 'Ningún insumo coincide con los filtros.',
          )
        else ...[
          _ListCard(
            children: [
              for (final item in rows)
                _SupplyRow(
                  item: item,
                  currency: currency,
                  onEntry: () => _openMovementDialog(item, 'purchase'),
                  onExit: () => _openMovementDialog(item, 'usage'),
                  onHistory: () => _selectTab('movimientos', item.id),
                  onEdit: () => _openSupplyDialog(item),
                ),
            ],
          ),
          const SizedBox(height: 12),
          BasePagination(
            total: filtered.length,
            page: page,
            pageSize: _stockPageSize,
            itemLabel: 'insumos',
            onPageChanged: (value) => setState(() => _stockPage = value),
            onPageSizeChanged: (value) => setState(() => _stockPageSize = value),
          ),
        ],
      ],
    );
  }

  Widget _buildMovements(BuildContext context) {
    final c = context.colors;
    final currency = _site.currency;
    final itemFilter = GoRouterState.of(context).uri.queryParameters['insumo'];

    if (itemFilter != _lastItemFilter) {
      _lastItemFilter = itemFilter;
      _movementPage = 1;
    }

    final filtered = _movements
        .where((movement) => itemFilter == null || movement.itemId == itemFilter)
        .where((movement) => _typeFilter == 'all' || movement.type == _typeFilter)
        .toList();
    final itemName = itemFilter == null
        ? null
        : _supplies.where((item) => item.id == itemFilter).firstOrNull?.name ??
            _movements.where((m) => m.itemId == itemFilter).firstOrNull?.itemName ??
            'Insumo';
    final pageCount = max(1, (filtered.length / _movementPageSize).ceil());
    final page = min(_movementPage, pageCount);
    final rows = filtered.skip((page - 1) * _movementPageSize).take(_movementPageSize).toList();

    Widget chip(String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: _typeFilter == value,
            onSelected: (_) => setState(() {
              _typeFilter = value;
              _movementPage = 1;
            }),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (itemName != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InputChip(
                    label: Text(itemName),
                    selected: true,
                    showCheckmark: false,
                    onDeleted: () => _selectTab('movimientos'),
                    deleteButtonTooltipMessage: 'Ver todos los insumos',
                  ),
                ),
              chip('Todos', 'all'),
              for (final type in movementTypes) chip('${movementTypeLabel[type]}s', type),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _EmptyCard(message: 'No hay movimientos registrados${itemName != null ? ' para $itemName' : ''}.')
        else ...[
          _ListCard(
            children: [
              for (final movement in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _MovementTypeBadge(type: movement.type),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movement.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                            Text(
                              [
                                _formatDateTime(movement.createdAt),
                                if (movement.createdBy != null && movement.createdBy!.isNotEmpty) movement.createdBy!,
                                if (movement.reason.isNotEmpty) movement.reason,
                                if (movement.expenseId != null) 'en Gastos',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${movement.delta > 0 ? '+' : ''}${formatQuantity(movement.delta)} ${movement.unit}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: movement.delta > 0
                                  ? c.success
                                  : movement.delta < 0
                                      ? c.onSurface
                                      : c.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'queda ${formatQuantity(movement.stockAfter)}'
                            '${movement.type == 'purchase' && (movement.unitCost ?? 0) != 0 ? ' · ${formatMoney(movement.delta * movement.unitCost!, currency)}' : ''}',
                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          BasePagination(
            total: filtered.length,
            page: page,
            pageSize: _movementPageSize,
            itemLabel: 'movimientos',
            onPageChanged: (value) => setState(() => _movementPage = value),
            onPageSizeChanged: (value) => setState(() => _movementPageSize = value),
          ),
        ],
      ],
    );
  }
}

class _SupplyRow extends StatelessWidget {
  const _SupplyRow({
    required this.item,
    required this.currency,
    required this.onEntry,
    required this.onExit,
    required this.onHistory,
    required this.onEdit,
  });

  final Supply item;
  final String currency;
  final VoidCallback onEntry;
  final VoidCallback onExit;
  final VoidCallback onHistory;
  final VoidCallback onEdit;

  /// Barra de nivel: el mínimo queda a la mitad de la barra.
  double get _level => item.minStock > 0
      ? min(100, item.stock / (item.minStock * 2) * 100)
      : item.stock > 0
          ? 100
          : 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final levelColor = item.status == 'critical'
        ? c.error
        : item.status == 'low'
            ? c.warning
            : c.success;
    final width = max(item.stock > 0 ? 3.0 : 0.0, _level) / 100;
    final details = [
      supplyCategoryLabel[item.category] ?? item.category,
      if (item.supplier.isNotEmpty) item.supplier,
      if (item.unitCost != 0) '${formatMoney(item.unitCost, currency)}/${item.unit}',
    ].join(' · ');

    return Opacity(
      opacity: item.isActive ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
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
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                      Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusBadge(
                    tone: item.stock <= 0 ? 'danger' : inventoryStatusTone[item.status] ?? 'neutral',
                    label: item.stock <= 0 ? 'Agotado' : inventoryStatusLabel[item.status] ?? item.status,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${formatQuantity(item.stock)} ${item.unit}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                  const Spacer(),
                  Text('mín. ${formatQuantity(item.minStock)}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 6,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999))),
                        Container(
                          width: constraints.maxWidth * width,
                          decoration: BoxDecoration(color: levelColor, borderRadius: BorderRadius.circular(999)),
                        ),
                        Positioned(left: constraints.maxWidth / 2, top: 0, bottom: 0, child: Container(width: 1, color: c.outline)),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BaseButton(label: '+ Entrada', size: 'sm', onPressed: onEntry),
                IconButton(tooltip: 'Salida, merma o conteo de ${item.name}', onPressed: onExit, icon: const Icon(Icons.swap_horiz_rounded)),
                IconButton(tooltip: 'Historial de ${item.name}', onPressed: onHistory, icon: const Icon(Icons.history_rounded)),
                IconButton(tooltip: 'Editar ${item.name}', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementTypeBadge extends StatelessWidget {
  const _MovementTypeBadge({required this.type});

  final MovementType type;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color background, Color foreground) = switch (type) {
      'purchase' => (c.successContainer, c.onSuccessContainer),
      'waste' => (c.errorContainer, c.onErrorContainer),
      'count' => (c.secondaryContainer, c.onSecondaryContainer),
      _ => (c.surfaceContainer, c.onSurfaceVariant),
    };

    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        movementTypeLabel[type] ?? type,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4)),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(16)),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(8)),
        child: Text(message, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
      ),
    );
  }
}
