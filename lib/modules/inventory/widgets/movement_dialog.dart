import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../api.dart';
import '../types.dart';

/// Cantidad con hasta 3 decimales en formato español (equivale a `Intl.NumberFormat('es', { maximumFractionDigits: 3 })`).
String formatQuantity(num value) => (NumberFormat.decimalPattern('es')..maximumFractionDigits = 3).format(value);

double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Entrada, salida, merma o conteo físico de un insumo, con vista previa del stock resultante.
/// [onSave] devuelve true si se registró (la hoja se cierra).
class MovementDialog extends StatefulWidget {
  const MovementDialog({
    super.key,
    required this.item,
    required this.initialType,
    required this.currency,
    required this.canRegisterExpense,
    required this.onSave,
  });

  final Supply item;
  final MovementType initialType;
  final String currency;

  /// Si quien registra puede crear gastos (permiso de cuentas).
  final bool canRegisterExpense;
  final Future<bool> Function(MovementDraft draft) onSave;

  static Future<void> show(
    BuildContext context, {
    required Supply item,
    required MovementType initialType,
    required String currency,
    required bool canRegisterExpense,
    required Future<bool> Function(MovementDraft draft) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MovementDialog(
        item: item,
        initialType: initialType,
        currency: currency,
        canRegisterExpense: canRegisterExpense,
        onSave: onSave,
      ),
    );
  }

  @override
  State<MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<MovementDialog> {
  late MovementType _type = widget.initialType;
  final TextEditingController _quantity = TextEditingController();
  late final TextEditingController _unitCost =
      TextEditingController(text: widget.item.unitCost != 0 ? formatInput(widget.item.unitCost) : '');
  final TextEditingController _note = TextEditingController();
  late final TextEditingController _supplier = TextEditingController(text: widget.item.supplier);
  String _wasteReason = wasteReasons.first;
  late bool _registerExpense = widget.canRegisterExpense;
  bool _touched = false;
  bool _saving = false;

  static String formatInput(double value) => value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  void initState() {
    super.initState();
    _resetForType();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    _note.dispose();
    _supplier.dispose();
    super.dispose();
  }

  // El conteo parte del stock actual; el resto, de cero.
  void _resetForType() {
    _quantity.text = _type == 'count' ? formatInput(widget.item.stock) : '';
    _note.clear();
    _wasteReason = wasteReasons.first;
    _touched = false;
  }

  double get _quantityValue => _parse(_quantity.text) ?? 0;

  double get _nextStock => stockAfter(widget.item.stock, _type, _quantityValue);

  double get _total {
    final cost = _parse(_unitCost.text);
    return _type == 'purchase' && cost != null && cost != 0 ? cost * _quantityValue : 0;
  }

  String? get _quantityError {
    if (_type == 'count') {
      return _quantityValue >= 0 && _quantity.text.trim().isNotEmpty ? null : 'Indica el stock contado.';
    }

    if (_quantityValue <= 0) return 'La cantidad debe ser mayor que cero.';

    return _nextStock >= 0 ? null : 'Solo hay ${formatQuantity(widget.item.stock)} ${widget.item.unit} en stock.';
  }

  String? get _unitCostError {
    final cost = _parse(_unitCost.text);
    return _type == 'purchase' && cost != null && cost < 0 ? 'El costo no puede ser negativo.' : null;
  }

  Future<void> _submit() async {
    setState(() => _touched = true);

    if (_quantityError != null || _unitCostError != null) return;

    final cost = _parse(_unitCost.text);
    final draft = MovementDraft(
      type: _type,
      quantity: _quantityValue,
      unitCost: _type == 'purchase' && _unitCost.text.trim().isNotEmpty ? cost : null,
      reason: _type == 'waste' ? _wasteReason : _note.text,
      supplier: _supplier.text,
      registerExpense: _type == 'purchase' && _registerExpense && _total > 0,
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
    final item = widget.item;
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final nextStock = _nextStock;
    final quantity = _quantityValue;
    final total = _total;
    final label = movementTypeLabel[_type] ?? _type;

    return BaseDialogFrame(
      title: item.name,
      subtitle: 'Stock actual: ${formatQuantity(item.stock)} ${item.unit} · mínimo ${formatQuantity(item.minStock)} ${item.unit}',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).maybePop()),
          const Spacer(),
          BaseButton(label: 'Registrar ${label.toLowerCase()}', variant: 'primary', loading: _saving, onPressed: _submit),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tipo
          Semantics(
            label: 'Tipo de movimiento',
            container: true,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in movementTypes)
                  ChoiceChip(
                    label: Text(movementTypeLabel[type] ?? type),
                    selected: _type == type,
                    onSelected: (_) => setState(() {
                      if (_type == type) return;
                      _type = type;
                      _resetForType();
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(movementTypeHint[_type] ?? '', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimal,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${_type == 'count' ? 'Stock contado' : 'Cantidad'} (${item.unit})',
                    hintText: '0',
                    errorText: _touched ? _quantityError : null,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              if (_type == 'purchase') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitCost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimal,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Costo por ${item.unit} (${widget.currency})',
                      errorText: _touched ? _unitCostError : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_type == 'waste') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('waste-reason'),
              initialValue: _wasteReason,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                helperText: 'El motivo elegido queda registrado en el historial.',
              ),
              items: [for (final reason in wasteReasons) DropdownMenuItem(value: reason, child: Text(reason))],
              onChanged: (value) => setState(() => _wasteReason = value ?? _wasteReason),
            ),
          ],
          if (_type == 'purchase') ...[
            const SizedBox(height: 16),
            TextField(controller: _supplier, decoration: const InputDecoration(labelText: 'Proveedor', hintText: 'Ej: Mercado Central')),
          ],
          if (_type != 'waste') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: _type == 'purchase'
                    ? 'Nº de factura o remito'
                    : _type == 'count'
                        ? 'Ej: Inventario de cierre de mes'
                        : 'Ej: Servicio de la noche',
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Vista previa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Stock '),
                    TextSpan(text: formatQuantity(item.stock), style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
                    const TextSpan(text: ' → '),
                    TextSpan(
                      text: '${formatQuantity(nextStock)} ${item.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: nextStock < 0
                            ? c.error
                            : nextStock < item.minStock
                                ? c.warning
                                : c.onSurface,
                      ),
                    ),
                    if (_type == 'count' && quantity != item.stock)
                      TextSpan(
                        text: ' (${nextStock > item.stock ? '+' : ''}${formatQuantity(nextStock - item.stock)} de diferencia)',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ]),
                  style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                ),
                if (_type == 'purchase' && total > 0)
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Total '),
                      TextSpan(
                        text: formatMoney(total, widget.currency),
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                      ),
                    ]),
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (_type == 'purchase' && widget.canRegisterExpense) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _registerExpense,
              onChanged: (value) => setState(() => _registerExpense = value ?? _registerExpense),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Registrar también como gasto'),
              subtitle: const Text('Se agrega en Cuentas → Gastos, categoría Insumos, con el total de la compra.'),
            ),
          ],
        ],
      ),
    );
  }
}
