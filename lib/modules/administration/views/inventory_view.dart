import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/empty_state.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../admin_labels.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/admin_form.dart';
import '../widgets/inventory_item_dialog.dart';

/// Inventario básico de insumos por sede (equivale a InventoryView.vue).
class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  List<InventoryItem> _items = [];
  List<RestaurantSite> _restaurants = [];
  String? _loadError;
  String? _actionError;
  bool _isLoading = true;

  /// 'all' | id de sede
  String _restaurantFilter = 'all';
  bool _alertOnly = false;
  bool _showInactive = false;

  /// Cantidad que se está escribiendo para cada insumo antes de guardarla.
  final Map<String, double> _stockDraft = {};
  final Map<String, TextEditingController> _stockControllers = {};

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  SessionStore get _session => context.read<SessionStore>();

  List<RestaurantSite> get _accessibleRestaurants =>
      _restaurants.where((site) => _session.canAccessRestaurant(site.id)).toList();

  String _restaurantName(String restaurantId) =>
      _restaurants.where((restaurant) => restaurant.id == restaurantId).firstOrNull?.name ?? restaurantId;

  List<InventoryItem> get _filteredItems => _items.where((item) {
        if (!_session.canAccessRestaurant(item.restaurantId)) {
          return false;
        }

        if (_restaurantFilter != 'all' && item.restaurantId != _restaurantFilter) {
          return false;
        }

        if (!_showInactive && !item.isActive) {
          return false;
        }

        return !(_alertOnly && (item.status == 'ok' || !item.isActive));
      }).toList();

  int get _alertCount => _items.where((item) => item.isActive && item.status != 'ok').length;

  TextEditingController _controllerFor(InventoryItem item) {
    return _stockControllers.putIfAbsent(item.id, () => TextEditingController(text: formatQuantity(item.stock)));
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([fetchInventoryItems(), fetchRestaurants()]);
      _items = results[0] as List<InventoryItem>;
      _restaurants = results[1] as List<RestaurantSite>;
      _stockDraft.clear();

      for (final item in _items) {
        _stockControllers[item.id]?.text = formatQuantity(item.stock);
      }
    } catch (error) {
      _loadError = errorText(error, 'No se pudo cargar el inventario.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _replaceItem(InventoryItem updated) {
    _items = _items.map((current) => current.id == updated.id ? updated : current).toList();
  }

  Future<void> _setStock(InventoryItem item, double stock) async {
    setState(() => _actionError = null);

    try {
      final updated = await updateInventoryStock(item, stock);
      if (!mounted) return;
      setState(() {
        _replaceItem(updated);
        _stockDraft.remove(item.id);
        _stockControllers[item.id]?.text = formatQuantity(updated.stock);
      });
    } catch (error) {
      if (mounted) setState(() => _actionError = errorText(error, 'No se pudo actualizar el stock.'));
    }
  }

  Future<void> _restock(InventoryItem item) => _setStock(item, max(item.minStock * 2, item.stock));

  Future<void> _toggleActive(InventoryItem item) async {
    setState(() => _actionError = null);

    try {
      final updated = await updateInventoryItem(
        item.id,
        InventoryItemDraft(
          restaurantId: item.restaurantId,
          name: item.name,
          unit: item.unit,
          stock: item.stock,
          minStock: item.minStock,
          supplier: item.supplier,
          isActive: !item.isActive,
        ),
      );
      if (mounted) setState(() => _replaceItem(updated));
    } catch (_) {
      if (mounted) setState(() => _actionError = 'No se pudo actualizar el insumo.');
    }
  }

  Future<String?> _saveItem(InventoryItem? original, InventoryItemDraft draft) async {
    setState(() => _actionError = null);

    try {
      if (original != null) {
        final updated = await updateInventoryItem(original.id, draft);
        if (mounted) {
          setState(() {
            _replaceItem(updated);
            _stockDraft.remove(updated.id);
            _stockControllers[updated.id]?.text = formatQuantity(updated.stock);
          });
        }
      } else {
        final created = await createInventoryItem(draft);
        if (mounted) setState(() => _items = [..._items, created]);
      }

      return null;
    } catch (_) {
      return 'No se pudo guardar el insumo.';
    }
  }

  void _openDialog(InventoryItem? item) {
    InventoryItemDialog.show(
      context,
      item: item,
      restaurants: _accessibleRestaurants,
      defaultRestaurantId: _restaurantFilter == 'all' ? null : _restaurantFilter,
      onSave: (draft) => _saveItem(item, draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Se observa la sesión: las sedes visibles dependen de los permisos del usuario.
    context.watch<SessionStore>();
    final filtered = _filteredItems;
    final accessible = _accessibleRestaurants;

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminPageHeader(
            section: 'Inventario',
            title: 'Inventario básico',
            description: 'Registro manual de insumos por sede. Se marca en alerta lo que está por debajo del mínimo.',
            actions: [
              BaseButton(
                label: 'Insumo',
                icon: Icons.add_rounded,
                variant: 'primary',
                onPressed: _isLoading || _loadError != null ? null : () => _openDialog(null),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else ...[
            if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
            DropdownButtonFormField<String>(
              initialValue: _restaurantFilter == 'all' || accessible.any((site) => site.id == _restaurantFilter) ? _restaurantFilter : 'all',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sede', prefixIcon: Icon(Icons.storefront_outlined)),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Todas mis sedes')),
                for (final restaurant in accessible)
                  DropdownMenuItem(value: restaurant.id, child: Text(restaurant.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _restaurantFilter = value ?? 'all'),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('Solo alertas ($_alertCount)'),
                    selected: _alertOnly,
                    selectedColor: c.errorContainer,
                    avatar: _alertOnly ? null : Icon(Icons.warning_amber_rounded, size: 16, color: c.onSurfaceVariant),
                    onSelected: (value) => setState(() => _alertOnly = value),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(_showInactive ? 'Mostrando inactivos' : 'Mostrar inactivos'),
                    selected: _showInactive,
                    onSelected: (value) => setState(() => _showInactive = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const EmptyState(title: 'No hay insumos que coincidan con el filtro.', icon: 'search')
            else
              for (final item in filtered) ...[
                _InventoryCard(
                  item: item,
                  restaurantName: _restaurantName(item.restaurantId),
                  controller: _controllerFor(item),
                  draft: _stockDraft[item.id],
                  onDraftChanged: (value) => setState(() {
                    if (value == null) {
                      _stockDraft.remove(item.id);
                    } else {
                      _stockDraft[item.id] = value;
                    }
                  }),
                  onSaveStock: () => _setStock(item, _stockDraft[item.id] ?? item.stock),
                  onRestock: () => _restock(item),
                  onEdit: () => _openDialog(item),
                  onToggleActive: () => _toggleActive(item),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.restaurantName,
    required this.controller,
    required this.draft,
    required this.onDraftChanged,
    required this.onSaveStock,
    required this.onRestock,
    required this.onEdit,
    required this.onToggleActive,
  });

  final InventoryItem item;
  final String restaurantName;
  final TextEditingController controller;
  final double? draft;
  final ValueChanged<double?> onDraftChanged;
  final VoidCallback onSaveStock;
  final VoidCallback onRestock;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final changed = draft != null && draft != item.stock;
    final inAlert = item.isActive && item.status != 'ok';

    return AdminCard(
      dimmed: !item.isActive,
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
                    Text(
                      item.supplier.isEmpty ? 'Sin proveedor' : item.supplier,
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(restaurantName, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (!item.isActive)
                      const StatusBadge(tone: 'muted', label: 'Inactivo')
                    else
                      StatusBadge(
                        tone: inventoryStatusTone[item.status] ?? 'neutral',
                        label: inventoryStatusLabel[item.status] ?? item.status,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) => value == 'edit' ? onEdit() : onToggleActive(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'active', child: Text(item.isActive ? 'Desactivar' : 'Activar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Cantidad',
                      semanticCounterText: 'Cantidad de ${item.name}',
                    ),
                    onChanged: (text) {
                      final value = parseQuantity(text);
                      onDraftChanged(value);
                    },
                    onSubmitted: (_) => onSaveStock(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${item.unit} · mín. ${formatQuantity(item.minStock)}',
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                ),
                if (changed)
                  BaseButton(label: 'Guardar', variant: 'primary', size: 'sm', onPressed: onSaveStock)
                else if (inAlert)
                  BaseButton(label: 'Reabastecer', variant: 'primary', size: 'sm', onPressed: onRestock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
