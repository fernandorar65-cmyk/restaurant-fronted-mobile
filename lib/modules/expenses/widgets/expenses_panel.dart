import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_pagination.dart';
import '../../../widgets/base/kpi_tile.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../orders/api.dart' show errorMessage;
import '../../orders/widgets/service_ui.dart';
import '../api.dart';
import '../types.dart';
import 'expense_categories_dialog.dart';
import 'expense_dialog.dart';
import 'expense_icon.dart';

String _pad(int value) => value.toString().padLeft(2, '0');

String _todayIso() {
  final today = DateTime.now();
  return '${today.year}-${_pad(today.month)}-${_pad(today.day)}';
}

String _shiftMonth(String value, int delta) {
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1] + delta, 1);
  return '${date.year}-${_pad(date.month)}';
}

({String from, String to}) _monthRange(String value) {
  final parts = value.split('-').map(int.parse).toList();
  final lastDay = DateTime(parts[0], parts[1] + 1, 0).day;
  return (from: '$value-01', to: '$value-${_pad(lastDay)}');
}

/// Gastos de una sede por mes: insumos, sueldos, alquiler, servicios, etc.
/// Se inserta dentro de la lista de la vista (no se desplaza por sí mismo).
class ExpensesPanel extends StatefulWidget {
  const ExpensesPanel({super.key, required this.restaurantId, required this.currency});

  final String restaurantId;
  final String currency;

  @override
  State<ExpensesPanel> createState() => _ExpensesPanelState();
}

class _ExpensesPanelState extends State<ExpensesPanel> {
  final String _today = _todayIso();

  /// Mes visible, YYYY-MM.
  late String _month = _today.substring(0, 7);
  List<Expense> _expenses = const [];
  final ValueNotifier<List<ExpenseCategory>> _categories = ValueNotifier(const []);
  bool _isLoading = true;
  String? _loadError;

  /// 'all' o id de categoría.
  String _categoryFilter = 'all';

  /// 'all' | 'fixed' | 'variable'
  String _kindFilter = 'all';
  int _page = 1;
  int _pageSize = 15;
  bool _copying = false;

  bool get _isCurrentMonth => _month == _today.substring(0, 7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExpensesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId) _load();
  }

  @override
  void dispose() {
    _categories.dispose();
    super.dispose();
  }

  String get _monthLabel {
    final parts = _month.split('-').map(int.parse).toList();
    final label = DateFormat("MMMM 'de' y", 'es').format(DateTime(parts[0], parts[1], 1));
    return label[0].toUpperCase() + label.substring(1);
  }

  Future<void> _load() async {
    final range = _monthRange(_month);
    setState(() => _loadError = null);

    try {
      final results = await Future.wait<Object>([fetchExpenses(widget.restaurantId, range.from, range.to), fetchExpenseCategories()]);
      if (!mounted) return;
      setState(() {
        _expenses = results[0] as List<Expense>;
        _clampPage();
      });
      _categories.value = results[1] as List<ExpenseCategory>;
    } catch (error) {
      if (mounted) setState(() => _loadError = errorMessage(error, 'No se pudieron cargar los gastos.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setMonth(String month) {
    setState(() {
      _month = month;
      _page = 1;
    });
    _load();
  }

  ExpenseCategory? _categoryOf(String id) => _categories.value.where((category) => category.id == id).firstOrNull;

  String _categoryName(String id) => _categoryOf(id)?.name ?? 'Sin categoría';

  double get _total => _expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

  double _totalByKind(ExpenseKind kind) =>
      _expenses.where((expense) => expense.kind == kind).fold<double>(0, (sum, expense) => sum + expense.amount);

  List<({String category, double amount, int count, double share})> get _breakdown {
    final total = _total;
    final rows = [
      for (final category in _expenses.map((expense) => expense.category).toSet())
        () {
          final items = _expenses.where((expense) => expense.category == category).toList();
          final amount = items.fold<double>(0, (sum, expense) => sum + expense.amount);
          return (category: category, amount: amount, count: items.length, share: total > 0 ? amount / total : 0.0);
        }(),
    ];
    return rows..sort((a, b) => b.amount.compareTo(a.amount));
  }

  List<Expense> get _visible => _expenses
      .where(
        (expense) =>
            (_categoryFilter == 'all' || expense.category == _categoryFilter) && (_kindFilter == 'all' || expense.kind == _kindFilter),
      )
      .toList();

  /// Si al eliminar se vacía la última página, se retrocede a la anterior.
  void _clampPage() {
    _page = min(_page, max(1, (_visible.length / _pageSize).ceil()));
  }

  void _toggleCategory(String category) {
    setState(() {
      _categoryFilter = _categoryFilter == category ? 'all' : category;
      _page = 1;
    });
  }

  String _formatDay(String date) {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : DateFormat('d MMM', 'es').format(parsed);
  }

  /// Para un mes pasado se sugiere el último día de ese mes; para el actual, hoy.
  String get _defaultDate => _isCurrentMonth ? _today : _monthRange(_month).to;

  Future<bool> _save(Expense? expense, ExpenseDraft draft) async {
    final toast = context.read<ToastStore>();
    final createdBy = context.read<SessionStore>().user?.name;

    try {
      if (expense != null) {
        await updateExpense(expense.id, draft);
        toast.show('Gasto actualizado', tone: 'success', durationMs: 3000);
      } else {
        await createExpense(widget.restaurantId, draft, createdBy);
        toast.show(
          'Gasto registrado',
          message: '${draft.description} · ${formatMoney(draft.amount, widget.currency)}',
          tone: 'success',
          durationMs: 3000,
        );
      }

      if (!mounted) return true;

      if (draft.date.substring(0, 7) != _month) {
        _setMonth(draft.date.substring(0, 7));
      } else {
        await _load();
      }

      return true;
    } catch (error) {
      toast.show('No se pudo guardar el gasto', message: errorMessage(error, 'Inténtalo de nuevo.'), tone: 'error');
      return false;
    }
  }

  Future<void> _openDialog(Expense? expense) {
    return showExpenseDialog(
      context,
      expense: expense,
      categories: _categories,
      currency: widget.currency,
      defaultDate: _defaultDate,
      onSave: (draft) => _save(expense, draft),
      onManageCategories: _openCategories,
    );
  }

  void _openCategories() {
    showExpenseCategoriesDialog(context, categories: _categories, onChanged: _load);
  }

  Future<void> _remove(Expense expense) async {
    final toast = context.read<ToastStore>();
    final ok = await confirmAction(
      context,
      title: '¿Eliminar este gasto?',
      message: '${expense.description} · ${formatMoney(expense.amount, widget.currency)}',
      confirmLabel: 'Eliminar',
      tone: 'danger',
    );

    if (!ok) return;

    try {
      await deleteExpense(expense.id);
      if (!mounted) return;
      setState(() {
        _expenses = _expenses.where((item) => item.id != expense.id).toList();
        _clampPage();
      });
      toast.show('Gasto eliminado', tone: 'success', durationMs: 3000);
    } catch (error) {
      toast.show('No se pudo eliminar el gasto', message: errorMessage(error, 'Inténtalo de nuevo.'), tone: 'error');
    }
  }

  /// Copiar los gastos fijos del mes anterior (alquiler, sueldos…) para no cargarlos a mano.
  Future<void> _copyFixedFromPreviousMonth() async {
    final toast = context.read<ToastStore>();
    final createdBy = context.read<SessionStore>().user?.name;
    final month = _month;
    final previous = _shiftMonth(month, -1);
    setState(() => _copying = true);

    try {
      final range = _monthRange(previous);
      final fixed = (await fetchExpenses(widget.restaurantId, range.from, range.to)).where((expense) => expense.kind == 'fixed').toList();
      String key(Expense expense) => '${expense.category}|${expense.description.trim().toLowerCase()}';
      final current = _monthRange(month);

      Future<List<Expense>> missing() async {
        final existing = (await fetchExpenses(widget.restaurantId, current.from, current.to)).map(key).toSet();
        return fixed.where((expense) => !existing.contains(key(expense))).toList();
      }

      final pending = await missing();

      if (pending.isEmpty) {
        toast.show(fixed.isEmpty ? 'El mes anterior no tiene gastos fijos' : 'Los gastos fijos ya están cargados', durationMs: 3000);
        return;
      }

      // json-server puede perder una escritura que llega mientras recarga db.json: se comprueba y se reintenta.
      var left = pending;
      for (var attempt = 0; attempt < 4 && left.isNotEmpty; attempt++) {
        for (final expense in left) {
          final day = expense.date.substring(8, 10);
          final candidate = '$month-$day';
          final date = candidate.compareTo(current.to) > 0 ? current.to : candidate;
          await createExpense(widget.restaurantId, ExpenseDraft.fromExpense(expense).copyWith(date: date), createdBy);
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
        left = await missing();
      }

      toast.show(
        '${pending.length} gastos fijos copiados',
        message: 'Revisa los importes por si cambiaron.',
        tone: 'success',
        durationMs: 4000,
      );
      await _load();
    } catch (error) {
      toast.show('No se pudieron copiar los gastos', message: errorMessage(error, 'Inténtalo de nuevo.'), tone: 'error');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _setMonth(_shiftMonth(_month, -1)),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _monthLabel,
                    textAlign: TextAlign.center,
                    style: AppFonts.headline(fontSize: 15, color: c.onSurface),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _isCurrentMonth ? null : () => _setMonth(_shiftMonth(_month, 1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BaseButton(label: 'Categorías', variant: 'ghost', onPressed: _openCategories),
            BaseButton(label: 'Copiar fijos del mes anterior', loading: _copying, onPressed: _copyFixedFromPreviousMonth),
            BaseButton(label: '+ Registrar gasto', variant: 'primary', onPressed: () => _openDialog(null)),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const SkeletonBlock(variant: 'page')
        else if (_loadError != null)
          InlineAlert(_loadError!)
        else
          ..._content(context),
      ],
    );
  }

  List<Widget> _content(BuildContext context) {
    final c = context.colors;
    final breakdown = _breakdown;
    final visible = _visible;
    final shown = visible.skip((_page - 1) * _pageSize).take(_pageSize).toList();
    final visibleTotal = visible.fold<double>(0, (sum, expense) => sum + expense.amount);

    Widget kpiRow(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );

    return [
      kpiRow(
        KpiTile(label: 'Total del mes', value: formatMoney(_total, widget.currency)),
        KpiTile(label: 'Gastos fijos', value: formatMoney(_totalByKind('fixed'), widget.currency)),
      ),
      const SizedBox(height: 12),
      kpiRow(
        KpiTile(label: 'Gastos variables', value: formatMoney(_totalByKind('variable'), widget.currency)),
        KpiTile(label: 'Registros', value: '${_expenses.length}'),
      ),
      const SizedBox(height: 16),
      if (_expenses.isEmpty)
        SurfaceCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text(
                'Sin gastos en ${_monthLabel.toLowerCase()}',
                textAlign: TextAlign.center,
                style: AppFonts.headline(fontSize: 16, color: c.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Registra insumos, sueldos, alquiler y demás gastos de la sede.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
            ],
          ),
        )
      else ...[
        SurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text('POR CATEGORÍA', style: AppFonts.eyebrow(color: c.outline)),
              ),
              for (final row in breakdown)
                Semantics(
                  button: true,
                  selected: _categoryFilter == row.category,
                  child: Material(
                    color: _categoryFilter == row.category ? c.primaryFixed.withValues(alpha: 0.5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleCategory(row.category),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _categoryName(row.category),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                                  ),
                                ),
                                Text(formatMoney(row.amount, widget.currency), style: tabular(TextStyle(fontSize: 14, color: c.onSurface))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: max(0.02, row.share),
                                      minHeight: 6,
                                      color: c.primary,
                                      backgroundColor: c.surfaceContainer,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${(row.share * 100).round()}%',
                                    textAlign: TextAlign.right,
                                    style: tabular(TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _categoryFilter == 'all',
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _categoryFilter = 'all';
                  _page = 1;
                }),
              ),
              for (final row in breakdown) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(_categoryName(row.category)),
                  selected: _categoryFilter == row.category,
                  showCheckmark: false,
                  onSelected: (_) => _toggleCategory(row.category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: DropdownButton<String>(
            value: _kindFilter,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Fijos y variables')),
              DropdownMenuItem(value: 'fixed', child: Text('Solo fijos')),
              DropdownMenuItem(value: 'variable', child: Text('Solo variables')),
            ],
            onChanged: (value) => setState(() {
              _kindFilter = value ?? 'all';
              _page = 1;
            }),
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          SurfaceCard(
            child: Text('Ningún gasto coincide con los filtros.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          )
        else ...[
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, expense) in shown.indexed) ...[
                  if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4)),
                  _expenseRow(context, expense),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          BasePagination(
            total: visible.length,
            page: _page,
            pageSize: _pageSize,
            itemLabel: 'gastos',
            onPageChanged: (page) => setState(() => _page = page),
            onPageSizeChanged: (size) => setState(() => _pageSize = size),
          ),
        ],
        if (_categoryFilter != 'all' || _kindFilter != 'all') ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              children: [
                const TextSpan(text: 'Subtotal filtrado: '),
                TextSpan(
                  text: formatMoney(visibleTotal, widget.currency),
                  style: tabular(TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                ),
              ],
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ],
    ];
  }

  Widget _expenseRow(BuildContext context, Expense expense) {
    final c = context.colors;
    final details = [
      _formatDay(expense.date),
      _categoryName(expense.category),
      if (expense.supplier != null) expense.supplier!,
      expensePaymentMethodLabel[expense.paymentMethod] ?? expense.paymentMethod,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(expenseIconData(_categoryOf(expense.category)?.icon), size: 20, color: c.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                ),
                Row(
                  children: [
                    Text(
                      formatMoney(expense.amount, widget.currency),
                      style: tabular(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      expenseKindLabel[expense.kind] ?? expense.kind,
                      background: expense.kind == 'fixed' ? c.secondaryContainer : c.surfaceContainer,
                      foreground: expense.kind == 'fixed' ? c.onSecondaryContainer : c.onSurfaceVariant,
                    ),
                  ],
                ),
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar ${expense.description}',
            icon: Icon(Icons.edit_outlined, size: 20, color: c.onSurfaceVariant),
            onPressed: () => _openDialog(expense),
          ),
          IconButton(
            tooltip: 'Eliminar ${expense.description}',
            icon: Icon(Icons.close_rounded, size: 20, color: c.onSurfaceVariant),
            onPressed: () => _remove(expense),
          ),
        ],
      ),
    );
  }
}
