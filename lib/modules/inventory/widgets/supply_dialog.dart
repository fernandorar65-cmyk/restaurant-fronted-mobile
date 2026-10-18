import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../types.dart';

String _formatInput(double value) => value == value.roundToDouble() ? '${value.round()}' : '$value';

/// Alta o edición de un insumo. El stock inicial se pide solo al crear; después cambia con movimientos.
/// [onSave] devuelve true si se guardó (la hoja se cierra).
class SupplyDialog extends StatefulWidget {
  const SupplyDialog({super.key, required this.item, required this.currency, required this.onSave});

  final Supply? item;
  final String currency;
  final Future<bool> Function(SupplyDraft draft) onSave;

  static Future<void> show(
    BuildContext context, {
    Supply? item,
    required String currency,
    required Future<bool> Function(SupplyDraft draft) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SupplyDialog(item: item, currency: currency, onSave: onSave),
    );
  }

  @override
  State<SupplyDialog> createState() => _SupplyDialogState();
}

class _SupplyDialogState extends State<SupplyDialog> {
  Supply? get _item => widget.item;

  late final TextEditingController _name = TextEditingController(text: _item?.name ?? '');
  late SupplyCategory _category = _item?.category ?? 'produce';
  late String _unit = _item?.unit ?? 'kg';
  late final TextEditingController _stock = TextEditingController(text: _formatInput(_item?.stock ?? 0));
  late final TextEditingController _minStock = TextEditingController(text: _formatInput(_item?.minStock ?? 0));
  late final TextEditingController _unitCost = TextEditingController(text: _formatInput(_item?.unitCost ?? 0));
  late final TextEditingController _supplier = TextEditingController(text: _item?.supplier ?? '');
  late bool _isActive = _item?.isActive ?? true;
  bool _touched = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_name, _stock, _minStock, _unitCost, _supplier]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _units => supplyUnits.contains(_unit) ? supplyUnits : [_unit, ...supplyUnits];

  /// Número del campo; vacío cuenta como 0 y un texto inválido como NaN (falla la validación).
  double _number(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return 0;
    return double.tryParse(text) ?? double.nan;
  }

  String? get _nameError => _name.text.trim().isNotEmpty ? null : 'Escribe el nombre del insumo.';
  String? get _stockError => _number(_stock) >= 0 ? null : 'El stock no puede ser negativo.';
  String? get _minStockError => _number(_minStock) >= 0 ? null : 'El mínimo no puede ser negativo.';
  String? get _unitCostError => _number(_unitCost) >= 0 ? null : 'El costo no puede ser negativo.';

  Future<void> _submit() async {
    setState(() => _touched = true);

    if ([_nameError, _stockError, _minStockError, _unitCostError].any((error) => error != null)) return;

    final draft = SupplyDraft(
      name: _name.text,
      category: _category,
      unit: _unit,
      stock: _number(_stock),
      minStock: _number(_minStock),
      unitCost: _number(_unitCost),
      supplier: _supplier.text,
      isActive: _isActive,
    );

    setState(() => _saving = true);
    final saved = await widget.onSave(draft);

    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = _item;
    const gap = SizedBox(height: 16);
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    TextField numberField(TextEditingController controller, String label, String? error, {String? helper}) => TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: decimal,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            errorText: _touched ? error : null,
            helperText: helper,
            helperMaxLines: 2,
          ),
        );

    return BaseDialogFrame(
      title: item != null ? 'Editar insumo' : 'Nuevo insumo',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).maybePop()),
          const Spacer(),
          BaseButton(label: item != null ? 'Guardar cambios' : 'Crear insumo', variant: 'primary', loading: _saving, onPressed: _submit),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Tomate pera, Aceite de oliva',
              errorText: _touched ? _nameError : null,
            ),
          ),
          gap,
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final category in supplyCategories)
                DropdownMenuItem(value: category, child: Text(supplyCategoryLabel[category] ?? category)),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          gap,
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Unidad de medida'),
            items: [for (final unit in _units) DropdownMenuItem(value: unit, child: Text(unit))],
            onChanged: (value) => setState(() => _unit = value ?? _unit),
          ),
          if (item == null) ...[
            gap,
            numberField(_stock, 'Stock actual ($_unit)', _stockError),
          ],
          gap,
          numberField(_minStock, 'Stock mínimo ($_unit)', _minStockError, helper: 'Por debajo de esto, avisa para reponer.'),
          gap,
          numberField(_unitCost, 'Costo por $_unit (${widget.currency})', _unitCostError),
          gap,
          TextField(
            controller: _supplier,
            decoration: const InputDecoration(labelText: 'Proveedor habitual (opcional)', hintText: 'Ej: Mercado Central'),
          ),
          if (item != null) ...[
            gap,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: Text(
                'El stock (${_formatInput(item.stock)} ${item.unit}) se modifica registrando entradas, salidas, mermas o conteos.',
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value ?? _isActive),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Insumo activo'),
              subtitle: const Text('(los inactivos no aparecen en el stock ni en las alertas)'),
            ),
          ],
        ],
      ),
    );
  }
}
