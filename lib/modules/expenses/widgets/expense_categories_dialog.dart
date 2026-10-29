import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/string.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../orders/api.dart' show errorMessage;
import '../../orders/widgets/service_ui.dart';
import '../api.dart';
import '../types.dart';
import 'expense_icon.dart';

/// Abre la gestión de categorías de gasto. [categories] es la lista viva del panel; [onChanged]
/// la recarga tras cada alta, edición o eliminación.
Future<void> showExpenseCategoriesDialog(
  BuildContext context, {
  required ValueListenable<List<ExpenseCategory>> categories,
  required Future<void> Function() onChanged,
}) {
  return showServiceSheet<void>(
    context,
    builder: (_) => ValueListenableBuilder<List<ExpenseCategory>>(
      valueListenable: categories,
      builder: (context, list, _) => ExpenseCategoriesDialog(categories: list, onChanged: onChanged),
    ),
  );
}

/// Categorías de gasto de la organización: agregar, editar y eliminar.
/// Al eliminar una categoría con gastos, se elige a qué categoría pasan.
class ExpenseCategoriesDialog extends StatefulWidget {
  const ExpenseCategoriesDialog({super.key, required this.categories, required this.onChanged});

  final List<ExpenseCategory> categories;
  final Future<void> Function() onChanged;

  @override
  State<ExpenseCategoriesDialog> createState() => _ExpenseCategoriesDialogState();
}

class _ExpenseCategoriesDialogState extends State<ExpenseCategoriesDialog> {
  Map<String, int> _counts = {};
  bool _busy = false;
  String? _error;

  String? _editingId;
  final _name = TextEditingController();
  final _hint = TextEditingController();
  ExpenseKind _defaultKind = 'variable';
  ExpenseIcon _icon = 'dots';

  ({ExpenseCategory category, String moveTo})? _removing;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _name.dispose();
    _hint.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await countExpensesByCategory();
      if (mounted) setState(() => _counts = Map.of(counts));
    } catch (_) {
      // Sin conteo se puede seguir; al eliminar se pedirá destino igualmente.
    }
  }

  int _usage(String id) => _counts[id] ?? 0;

  void _startEdit(ExpenseCategory category) {
    setState(() {
      _editingId = category.id;
      _removing = null;
      _name.text = category.name;
      _hint.text = category.hint;
      _defaultKind = category.defaultKind;
      _icon = category.icon;
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _name.clear();
      _hint.clear();
      _defaultKind = 'variable';
      _icon = 'dots';
    });
  }

  String _uniqueId(String name) {
    final base = slugify(name).isEmpty ? 'categoria' : slugify(name);
    var id = base;
    for (var index = 2; widget.categories.any((category) => category.id == id); index++) {
      id = '$base-$index';
    }
    return id;
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    setState(() => _error = null);

    if (name.isEmpty) {
      setState(() => _error = 'La categoría necesita un nombre.');
      return;
    }

    if (widget.categories.any((category) => category.id != _editingId && category.name.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = 'Ya existe una categoría llamada "$name".');
      return;
    }

    setState(() => _busy = true);
    final draft = ExpenseCategoryDraft(name: _name.text, hint: _hint.text, defaultKind: _defaultKind, icon: _icon);

    try {
      if (_editingId != null) {
        await updateExpenseCategory(_editingId!, draft);
      } else {
        await createExpenseCategory(_uniqueId(name), draft);
      }
      if (!mounted) return;
      _resetForm();
      await widget.onChanged();
    } catch (cause) {
      if (mounted) setState(() => _error = errorMessage(cause, 'No se pudo guardar la categoría.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _askRemove(ExpenseCategory category) {
    if (_editingId == category.id) _resetForm();
    final fallback = widget.categories.where((item) => item.id != category.id).firstOrNull;
    setState(() => _removing = (category: category, moveTo: fallback?.id ?? ''));
  }

  Future<void> _confirmRemove() async {
    final removing = _removing;
    if (removing == null) return;
    final (:category, :moveTo) = removing;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final used = _usage(category.id);
      await deleteExpenseCategory(category.id, used > 0 ? moveTo : null);
      if (!mounted) return;
      setState(() {
        if (used > 0) {
          _counts[moveTo] = _usage(moveTo) + used;
          _counts.remove(category.id);
        }
        _removing = null;
      });
      await widget.onChanged();
    } catch (cause) {
      if (mounted) setState(() => _error = errorMessage(cause, 'No se pudo eliminar la categoría.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.onSurfaceVariant);
    final removing = _removing;

    return BaseDialogFrame(
      title: 'Categorías de gasto',
      subtitle: 'Se comparten entre todas las sedes.',
      footer: Align(
        alignment: Alignment.centerRight,
        child: BaseButton(label: 'Listo', variant: 'primary', onPressed: () => Navigator.of(context).pop()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                for (final (index, category) in widget.categories.indexed) ...[
                  if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                              child: Icon(expenseIconData(category.icon), size: 20, color: c.onSurfaceVariant),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                                  ),
                                  Text(
                                    '${expenseKindLabel[category.defaultKind]} · ${_usage(category.id)} ${_usage(category.id) == 1 ? 'gasto' : 'gastos'}'
                                    '${category.hint.isNotEmpty ? ' · ${category.hint}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar ${category.name}',
                              icon: Icon(Icons.edit_outlined, size: 20, color: c.onSurfaceVariant),
                              onPressed: () => _startEdit(category),
                            ),
                            IconButton(
                              tooltip: widget.categories.length <= 1 ? 'Debe quedar al menos una categoría' : 'Eliminar ${category.name}',
                              icon: Icon(Icons.close_rounded, size: 20, color: c.onSurfaceVariant),
                              onPressed: widget.categories.length <= 1 ? null : () => _askRemove(category),
                            ),
                          ],
                        ),
                        if (removing != null && removing.category.id == category.id)
                          Container(
                            margin: const EdgeInsets.only(top: 8, right: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: c.errorContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_usage(category.id) > 0)
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Sus ${_usage(category.id)} gastos pasan a',
                                        style: TextStyle(fontSize: 14, color: c.onErrorContainer),
                                      ),
                                      DropdownButton<String>(
                                        value: removing.moveTo.isEmpty ? null : removing.moveTo,
                                        items: [
                                          for (final target in widget.categories.where((item) => item.id != category.id))
                                            DropdownMenuItem(value: target.id, child: Text(target.name)),
                                        ],
                                        onChanged: (value) =>
                                            setState(() => _removing = (category: category, moveTo: value ?? removing.moveTo)),
                                      ),
                                    ],
                                  )
                                else
                                  Text('No tiene gastos registrados.', style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    BaseButton(
                                      label: 'Cancelar',
                                      variant: 'ghost',
                                      size: 'sm',
                                      onPressed: () => setState(() => _removing = null),
                                    ),
                                    BaseButton(
                                      label: 'Eliminar «${category.name}»',
                                      variant: 'danger',
                                      size: 'sm',
                                      loading: _busy,
                                      onPressed: _confirmRemove,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_editingId != null ? 'EDITAR CATEGORÍA' : 'NUEVA CATEGORÍA', style: AppFonts.eyebrow(color: c.outline)),
                const SizedBox(height: 12),
                Text('Nombre', style: labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(hintText: 'Ej: Delivery, Seguros, Limpieza'),
                ),
                const SizedBox(height: 12),
                Text('Tipo sugerido', style: labelStyle),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey('kind-$_editingId'),
                  initialValue: _defaultKind,
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('Fijo')),
                    DropdownMenuItem(value: 'variable', child: Text('Variable')),
                  ],
                  onChanged: (value) => setState(() => _defaultKind = value ?? _defaultKind),
                ),
                const SizedBox(height: 12),
                Text('Descripción (opcional)', style: labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: _hint,
                  decoration: const InputDecoration(hintText: 'Qué gastos entran aquí'),
                ),
                const SizedBox(height: 12),
                Text('Ícono', style: labelStyle),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final icon in expenseIcons.keys)
                      Semantics(
                        button: true,
                        selected: _icon == icon,
                        label: 'Ícono $icon',
                        excludeSemantics: true,
                        child: Material(
                          color: _icon == icon ? c.primaryFixed.withValues(alpha: 0.5) : c.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _icon == icon ? c.primaryInk : c.outlineVariant.withValues(alpha: 0.5),
                              width: _icon == icon ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _icon = icon),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(expenseIconData(icon), size: 20, color: _icon == icon ? c.primaryInk : c.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_editingId != null) BaseButton(label: 'Cancelar edición', variant: 'ghost', onPressed: _resetForm),
                    BaseButton(
                      label: _editingId != null ? 'Guardar cambios' : 'Agregar categoría',
                      loading: _busy && _removing == null,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 12), InlineAlert(_error!)],
        ],
      ),
    );
  }
}
