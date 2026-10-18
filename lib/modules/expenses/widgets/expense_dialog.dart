import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../orders/widgets/service_ui.dart';
import '../types.dart';
import 'expense_icon.dart';

/// Abre el alta (expense == null) o edición de un gasto. [onSave] devuelve true si se guardó
/// (la hoja se cierra); [onManageCategories] abre la gestión de categorías encima.
Future<void> showExpenseDialog(
  BuildContext context, {
  Expense? expense,
  required ValueListenable<List<ExpenseCategory>> categories,
  required String currency,
  required String defaultDate,
  required Future<bool> Function(ExpenseDraft draft) onSave,
  required VoidCallback onManageCategories,
}) {
  return showServiceSheet<void>(
    context,
    builder: (_) => ValueListenableBuilder<List<ExpenseCategory>>(
      valueListenable: categories,
      builder: (context, list, _) => ExpenseDialog(
        expense: expense,
        categories: list,
        currency: currency,
        defaultDate: defaultDate,
        onSave: onSave,
        onManageCategories: onManageCategories,
      ),
    ),
  );
}

/// Alta o edición de un gasto de la sede.
class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({
    super.key,
    required this.expense,
    required this.categories,
    required this.currency,
    required this.defaultDate,
    required this.onSave,
    required this.onManageCategories,
  });

  /// null = gasto nuevo.
  final Expense? expense;
  final List<ExpenseCategory> categories;
  final String currency;

  /// Fecha sugerida para un gasto nuevo (YYYY-MM-DD).
  final String defaultDate;
  final Future<bool> Function(ExpenseDraft draft) onSave;
  final VoidCallback onManageCategories;

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  late String _category;
  late ExpenseKind _kind;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late String _date;
  late final TextEditingController _supplier;
  late ExpensePaymentMethod _paymentMethod;
  late final TextEditingController _notes;
  bool _touched = false;
  bool _saving = false;

  /// Si la persona eligió el tipo a mano, cambiar de categoría ya no lo pisa.
  late bool _kindChosenByUser;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    final first = widget.categories.firstOrNull;
    _category = expense?.category ?? first?.id ?? '';
    _kind = expense?.kind ?? first?.defaultKind ?? 'variable';
    _description = TextEditingController(text: expense?.description ?? '')..addListener(_refresh);
    _amount = TextEditingController(text: expense != null ? expense.amount.toStringAsFixed(2) : '')..addListener(_refresh);
    _date = expense?.date ?? widget.defaultDate;
    _supplier = TextEditingController(text: expense?.supplier ?? '');
    _paymentMethod = expense?.paymentMethod ?? 'transfer';
    _notes = TextEditingController(text: expense?.notes ?? '');
    _kindChosenByUser = expense != null;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _supplier.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_touched && mounted) setState(() {});
  }

  ExpenseCategory? get _selectedCategory => widget.categories.where((category) => category.id == _category).firstOrNull;

  double get _amountValue => double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;

  Map<String, String?> get _errors => {
    'category': _selectedCategory != null ? null : 'Elige una categoría.',
    'description': _description.text.trim().isNotEmpty ? null : 'Describe el gasto.',
    'amount': _amountValue > 0 ? null : 'El importe debe ser mayor que cero.',
    'date': _date.isNotEmpty ? null : 'Indica la fecha.',
  };

  void _chooseCategory(ExpenseCategory category) {
    setState(() {
      _category = category.id;
      if (!_kindChosenByUser) _kind = category.defaultKind;
    });
  }

  void _chooseKind(ExpenseKind kind) {
    setState(() {
      _kind = kind;
      _kindChosenByUser = true;
    });
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));

    if (picked != null && mounted) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _submit() async {
    setState(() => _touched = true);

    if (_errors.values.any((error) => error != null)) {
      return;
    }

    final supplier = _supplier.text.trim();
    final draft = ExpenseDraft(
      category: _category,
      kind: _kind,
      description: _description.text,
      amount: _amountValue,
      date: _date,
      supplier: supplier.isEmpty ? null : supplier,
      paymentMethod: _paymentMethod,
      notes: _notes.text,
    );
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final saved = await widget.onSave(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) navigator.pop();
  }

  String? _error(String key) => _touched ? _errors[key] : null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _selectedCategory;
    final labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.onSurfaceVariant);

    Widget errorText(String key) {
      final message = _error(key);
      return message == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message, style: TextStyle(fontSize: 12, color: c.error)),
            );
    }

    return BaseDialogFrame(
      title: widget.expense != null ? 'Editar gasto' : 'Registrar gasto',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).pop()),
          const Spacer(),
          BaseButton(
            label: widget.expense != null ? 'Guardar cambios' : 'Registrar gasto',
            variant: 'primary',
            loading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Categoría', style: labelStyle)),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: widget.onManageCategories,
                child: Text('Gestionar categorías', style: AppFonts.label(fontSize: 13, color: c.primary)),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth >= 520 ? 4 : 2;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final category in widget.categories)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        selected: _category == category.id,
                        child: Material(
                          color: _category == category.id ? c.primaryFixed.withValues(alpha: 0.5) : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _category == category.id ? c.primary : c.outlineVariant.withValues(alpha: 0.5),
                              width: _category == category.id ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _chooseCategory(category),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    expenseIconData(category.icon),
                                    size: 20,
                                    color: _category == category.id ? c.primary : c.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    category.name,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (selected != null && selected.hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(selected.hint, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          ],
          errorText('category'),
          const SizedBox(height: 16),
          Text('Tipo de gasto', style: labelStyle),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final kind in const ['fixed', 'variable'])
                ButtonSegment(
                  value: kind,
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(expenseKindLabel[kind]!),
                        Text(
                          kind == 'fixed' ? 'Se repite cada mes' : 'Depende del movimiento',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (value) => _chooseKind(value.first),
          ),
          const SizedBox(height: 16),
          Text('Descripción', style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: selected != null ? 'Ej: ${selected.hint.isNotEmpty ? selected.hint : selected.name}' : 'Describe el gasto',
            ),
          ),
          errorText('description'),
          const SizedBox(height: 16),
          Text('Importe (${widget.currency})', style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: tabular(const TextStyle()),
            decoration: const InputDecoration(hintText: '0,00'),
          ),
          errorText('amount'),
          const SizedBox(height: 16),
          Text('Fecha', style: labelStyle),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(_date.isEmpty ? 'Elegir fecha' : DateFormat('d MMM y', 'es').format(DateTime.tryParse(_date) ?? DateTime.now())),
            ),
          ),
          errorText('date'),
          const SizedBox(height: 16),
          Text('Proveedor o beneficiario (opcional)', style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: _supplier,
            decoration: const InputDecoration(hintText: 'Ej: Mercado Central, Iberdrola'),
          ),
          const SizedBox(height: 16),
          Text('Pagado con', style: labelStyle),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            items: [for (final entry in expensePaymentMethodLabel.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
            onChanged: (value) => setState(() => _paymentMethod = value ?? _paymentMethod),
          ),
          const SizedBox(height: 16),
          Text('Notas (opcional)', style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Nº de factura, detalle, etc.'),
          ),
        ],
      ),
    );
  }
}
