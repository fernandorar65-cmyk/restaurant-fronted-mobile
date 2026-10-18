import 'package:flutter/material.dart';

import '../../../widgets/base/base_dialog.dart';
import '../../restaurants/types.dart';
import '../types.dart';
import 'admin_form.dart';
import 'employee_dialog.dart' show DraftSaver;

const List<String> _units = ['ud', 'kg', 'g', 'l', 'ml', 'botella', 'caja'];

/// Muestra una cantidad sin decimales sobrantes ("2" y no "2.0").
String formatQuantity(num value) => value == value.roundToDouble() ? '${value.round()}' : '$value';

/// Lee un número escrito con coma o punto decimal.
double? parseQuantity(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Alta / edición de un insumo (equivale a InventoryItemDialog.vue).
class InventoryItemDialog extends StatefulWidget {
  const InventoryItemDialog({
    super.key,
    required this.item,
    required this.restaurants,
    required this.defaultRestaurantId,
    required this.onSave,
  });

  final InventoryItem? item;
  final List<RestaurantSite> restaurants;
  final String? defaultRestaurantId;
  final DraftSaver<InventoryItemDraft> onSave;

  static Future<void> show(
    BuildContext context, {
    InventoryItem? item,
    required List<RestaurantSite> restaurants,
    String? defaultRestaurantId,
    required DraftSaver<InventoryItemDraft> onSave,
  }) {
    return showBaseDialog<void>(
      context,
      title: item != null ? 'Editar ${item.name}' : 'Nuevo insumo',
      builder: (_) => InventoryItemDialog(
        item: item,
        restaurants: restaurants,
        defaultRestaurantId: defaultRestaurantId,
        onSave: onSave,
      ),
    );
  }

  @override
  State<InventoryItemDialog> createState() => _InventoryItemDialogState();
}

class _InventoryItemDialogState extends State<InventoryItemDialog> {
  late String _restaurantId = widget.item?.restaurantId ?? widget.defaultRestaurantId ?? widget.restaurants.firstOrNull?.id ?? '';
  late final TextEditingController _name = TextEditingController(text: widget.item?.name ?? '');
  late final TextEditingController _unit = TextEditingController(text: widget.item?.unit ?? 'ud');
  late final TextEditingController _stock = TextEditingController(text: formatQuantity(widget.item?.stock ?? 0));
  late final TextEditingController _minStock = TextEditingController(text: formatQuantity(widget.item?.minStock ?? 0));
  late final TextEditingController _supplier = TextEditingController(text: widget.item?.supplier ?? '');
  late bool _isActive = widget.item?.isActive ?? true;
  String? _formError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _stock.dispose();
    _minStock.dispose();
    _supplier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _restaurantId.isEmpty) {
      setState(() => _formError = 'Indica el nombre y la sede del insumo.');
      return;
    }

    final stock = parseQuantity(_stock.text) ?? 0;
    final minStock = parseQuantity(_minStock.text) ?? 0;

    if (stock < 0 || minStock < 0) {
      setState(() => _formError = 'Las cantidades no pueden ser negativas.');
      return;
    }

    setState(() {
      _formError = null;
      _saving = true;
    });

    final navigator = Navigator.of(context);
    final unit = _unit.text.trim();
    final error = await widget.onSave(
      InventoryItemDraft(
        restaurantId: _restaurantId,
        name: _name.text.trim(),
        unit: unit.isEmpty ? 'ud' : unit,
        stock: stock,
        minStock: minStock,
        supplier: _supplier.text.trim(),
        isActive: _isActive,
      ),
    );

    if (!mounted) return;

    if (error == null) {
      navigator.pop();
    } else {
      setState(() {
        _saving = false;
        _formError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    final restaurantValue = widget.restaurants.any((site) => site.id == _restaurantId) ? _restaurantId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
        fieldGap,
        DropdownButtonFormField<String>(
          initialValue: restaurantValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sede'),
          items: [
            for (final site in widget.restaurants)
              DropdownMenuItem(value: site.id, child: Text(site.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) => setState(() => _restaurantId = value ?? ''),
        ),
        fieldGap,
        TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unidad')),
        const SizedBox(height: 8),
        // Sugerencias de unidad (equivale al <datalist> del formulario web).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in _units)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: _unit.text.trim() == option,
                    onSelected: (_) => setState(() => _unit.text = option),
                  ),
                ),
            ],
          ),
        ),
        fieldGap,
        FieldPair(
          first: TextField(
            controller: _stock,
            keyboardType: numberKeyboard,
            decoration: const InputDecoration(labelText: 'Cantidad actual'),
          ),
          second: TextField(
            controller: _minStock,
            keyboardType: numberKeyboard,
            decoration: const InputDecoration(labelText: 'Cantidad mínima'),
          ),
        ),
        fieldGap,
        TextField(controller: _supplier, decoration: const InputDecoration(labelText: 'Proveedor (referencia)')),
        const SizedBox(height: 6),
        SwitchListTile(
          value: _isActive,
          contentPadding: EdgeInsets.zero,
          title: const Text('Insumo activo', style: TextStyle(fontSize: 14)),
          onChanged: (value) => setState(() => _isActive = value),
        ),
        if (_formError != null) ...[fieldGap, InlineAlert(_formError!)],
        const SizedBox(height: 20),
        DialogActions(onSubmit: _submit, loading: _saving),
      ],
    );
  }
}
