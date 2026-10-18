import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../menus/api.dart';
import '../../menus/types.dart';
import '../../menus/widgets/quantity_stepper.dart';
import '../../restaurants/api.dart';
import '../../restaurants/site_labels.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../types.dart';
import 'service_ui.dart';

/// Abre el pedido manual. Devuelve el id de la atención si se registró el pedido.
Future<String?> showStaffOrderDialog(BuildContext context, {required RestaurantSite restaurant, String? presetTableNumber}) {
  return showServiceSheet<String>(
    context,
    builder: (_) => StaffOrderDialog(restaurant: restaurant, presetTableNumber: presetTableNumber),
  );
}

class _DraftLine {
  _DraftLine(this.product, this.quantity);

  final MenuProduct product;
  int quantity;
  final TextEditingController notes = TextEditingController();
}

/// Pedido manual: el personal carga productos para una mesa (comensales que no usan el QR).
class StaffOrderDialog extends StatefulWidget {
  const StaffOrderDialog({super.key, required this.restaurant, this.presetTableNumber});

  final RestaurantSite restaurant;
  final String? presetTableNumber;

  @override
  State<StaffOrderDialog> createState() => _StaffOrderDialogState();
}

class _StaffOrderDialogState extends State<StaffOrderDialog> {
  List<LiveTable> _tables = const [];
  List<Attention> _activeAttentions = const [];
  List<MenuCategory> _categories = const [];
  List<MenuProduct> _products = const [];
  late String _tableNumber = widget.presetTableNumber ?? '';
  final _search = TextEditingController();
  List<_DraftLine> _lines = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _formError;

  /// Una sola clave por pedido: si se reintenta tras un error de red no se duplican productos.
  String _batchId = createId('batch');

  String get _currency => widget.restaurant.currency;

  String get _staffName => context.read<SessionStore>().user?.name ?? 'Personal';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _search.dispose();
    for (final line in _lines) {
      line.notes.dispose();
    }
    super.dispose();
  }

  LiveTable? get _selectedTable => _tables.where((table) => table.number == _tableNumber).firstOrNull;

  Attention? get _selectedAttention => _activeAttentions.where((attention) => attention.tableNumber == _tableNumber).firstOrNull;

  double get _total => _lines.fold<double>(0, (sum, line) => sum + line.product.price * line.quantity);

  int _quantityOf(String productId) => _lines.where((line) => line.product.id == productId).firstOrNull?.quantity ?? 0;

  void _changeQuantity(MenuProduct product, int delta) {
    setState(() {
      final line = _lines.where((item) => item.product.id == product.id).firstOrNull;

      if (line == null) {
        if (delta > 0) _lines = [..._lines, _DraftLine(product, delta)];
        return;
      }

      line.quantity += delta;

      if (line.quantity <= 0) {
        _lines = _lines.where((item) => item.product.id != product.id).toList();
        // Se libera cuando su campo ya salió del árbol.
        WidgetsBinding.instance.addPostFrameCallback((_) => line.notes.dispose());
      }
    });
  }

  bool _hasOpenAttention(LiveTable table) => _activeAttentions.any((item) => item.tableNumber == table.number);

  String _tableStateLabel(LiveTable table) {
    if (table.status != 'active') {
      return tableStatusLabel[table.status] ?? table.status;
    }

    return _hasOpenAttention(table) ? 'Ocupada' : 'Libre';
  }

  String _tableOptionLabel(LiveTable table) {
    final open = _hasOpenAttention(table);
    final status = table.status == 'active' ? '' : ' · ${tableStatusLabel[table.status] ?? table.status}';
    return 'Mesa ${table.number}${open ? ' · atención abierta' : ''}$status';
  }

  Future<void> _submit() async {
    if (_tableNumber.isEmpty || _lines.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });
    final navigator = Navigator.of(context);
    final staffName = _staffName;

    try {
      final issues = await validateOrderItems(
        widget.restaurant.id,
        _lines.map((line) => OrderItemCheck(productId: line.product.id, name: line.product.name, unitPrice: line.product.price)).toList(),
      );

      if (issues.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _formError = 'Revisa el pedido: ${issues.map((issue) => issue.name).join(', ')} ya no está disponible o cambió de precio.';
        });
        await _loadData();
        return;
      }

      final attention = await openOrReuseAttention(widget.restaurant.id, _tableNumber, userName: staffName);
      await addOrderedProducts(
        attention,
        _lines
            .map(
              (line) => NewOrderedProductInput(
                productId: line.product.id,
                name: line.product.name,
                unitPrice: line.product.price,
                quantity: line.quantity,
                notes: line.notes.text.trim(),
              ),
            )
            .toList(),
        OrderBatchOptions(batchId: _batchId, createdBy: staffName, customerId: null),
      );

      _batchId = createId('batch');
      navigator.pop(attention.id);
    } catch (error) {
      if (mounted) setState(() => _formError = errorMessage(error, 'No se pudo registrar el pedido. Inténtalo de nuevo.'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait<Object?>([
        fetchSiteOperation(widget.restaurant.id),
        fetchAttentionsBySite(widget.restaurant.id),
        fetchCustomerMenu(widget.restaurant.id),
      ]);
      final operation = results[0] as SiteOperation?;
      final attentions = results[1] as List<Attention>;
      final menu = results[2] as ({List<MenuCategory> categories, List<MenuProduct> products});
      if (!mounted) return;
      setState(() {
        _tables = operation?.tables ?? const [];
        _activeAttentions = attentions.where(isAttentionActive).toList();
        _categories = menu.categories;
        _products = menu.products;
      });
    } catch (error) {
      if (mounted) setState(() => _formError = errorMessage(error, 'No se pudo cargar la carta.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = _search.text.trim().toLowerCase();
    final filtered = _products.where((product) => query.isEmpty || product.name.toLowerCase().contains(query)).toList();
    final groups = [
      for (final category in _categories)
        (category: category, items: filtered.where((product) => product.categoryId == category.id).toList()),
    ].where((group) => group.items.isNotEmpty).toList();
    final selectedAttention = _selectedAttention;
    final selectedTable = _selectedTable;

    return BaseDialogFrame(
      eyebrow: 'Pedido manual',
      title: 'Cargar pedido para una mesa',
      subtitle: 'Para comensales que no usan el QR. Queda registrado a nombre de $_staffName.',
      footer: Row(
        children: [
          Expanded(
            child: Text(formatMoney(_total, _currency), style: tabular(AppFonts.headline(fontSize: 18, color: c.onSurface))),
          ),
          BaseButton(label: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
          BaseButton(
            label: _isSubmitting ? 'Enviando…' : 'Enviar pedido',
            variant: 'primary',
            disabled: _isSubmitting || _tableNumber.isEmpty || _lines.isEmpty,
            onPressed: _submit,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            Text('Cargando carta y mesas…', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))
          else ...[
            Text(
              '1. Elige la mesa',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final columns = constraints.maxWidth >= 480 ? 6 : 4;
                final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [for (final table in _tables) SizedBox(width: width, child: _tableButton(context, table))],
                );
              },
            ),
            const SizedBox(height: 10),
            if (selectedAttention != null)
              _note(
                context,
                'Se agregará a la atención abierta de la mesa ${selectedAttention.tableNumber}.',
                c.primaryFixed,
                c.onPrimaryFixed,
              )
            else if (selectedTable != null)
              _note(context, 'Se abrirá una nueva atención para la mesa ${selectedTable.number}.', c.surfaceContainer, c.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '2. Agrega productos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(hintText: 'Buscar producto…', prefixIcon: Icon(Icons.search_rounded)),
            ),
            if (_products.isEmpty) ...[
              const SizedBox(height: 12),
              Text('La sede no tiene un menú activo con productos.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            ],
            for (final group in groups) ...[
              const SizedBox(height: 16),
              Text(group.category.name.toUpperCase(), style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
              const SizedBox(height: 8),
              for (final product in group.items)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                            ),
                            Text(formatMoney(product.price, _currency), style: tabular(TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!product.isAvailable)
                        Text('AGOTADO', style: AppFonts.label(fontSize: 12, color: c.onSurfaceVariant))
                      else
                        QuantityStepper(
                          quantity: _quantityOf(product.id),
                          label: product.name,
                          onIncrease: () => _changeQuantity(product, 1),
                          onDecrease: () => _changeQuantity(product, -1),
                        ),
                    ],
                  ),
                ),
            ],
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('RESUMEN', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
                    for (final line in _lines) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text('${line.quantity}× ${line.product.name}', style: const TextStyle(fontSize: 14))),
                          Text(
                            formatMoney(line.product.price * line.quantity, _currency),
                            style: tabular(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        key: ValueKey('notes-${line.product.id}'),
                        controller: line.notes,
                        decoration: InputDecoration(
                          hintText: 'Observación (ej: sin cebolla)',
                          isDense: true,
                          filled: true,
                          fillColor: c.surfaceContainerLowest,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
          if (_formError != null) ...[const SizedBox(height: 12), InlineAlert(_formError!)],
        ],
      ),
    );
  }

  Widget _note(BuildContext context, String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(fontSize: 12, color: foreground)),
  );

  Widget _tableButton(BuildContext context, LiveTable table) {
    final c = context.colors;
    final selected = _tableNumber == table.number;
    final enabled = table.status == 'active';
    final open = _hasOpenAttention(table);
    final (Color background, Color foreground, Color border) = selected
        ? (c.primary, c.onPrimary, c.primary)
        : open
        ? (c.primaryFixed, c.onPrimaryFixed, Colors.transparent)
        : (c.surfaceContainerLowest, c.onSurface, c.outlineVariant.withValues(alpha: 0.5));

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: _tableOptionLabel(table),
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => setState(() => _tableNumber = table.number) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    table.number,
                    style: AppFonts.label(fontSize: 16, fontWeight: FontWeight.w700, color: foreground),
                  ),
                  Text(
                    _tableStateLabel(table),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: foreground.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
