import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../period.dart';
import '../types.dart';
import 'finance_formats.dart';

const List<({FinancePeriodKind value, String label})> _periods = [
  (value: 'day', label: 'Día'),
  (value: 'month', label: 'Mes'),
  (value: 'year', label: 'Año'),
];

/// Selector Día / Mes / Año con flechas y fecha. No permite ir más allá de hoy
/// (equivale a FinancePeriodPicker.vue).
class FinancePeriodPicker extends StatelessWidget {
  const FinancePeriodPicker({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  final FinancePeriodKind period;
  final String anchor;
  final ValueChanged<FinancePeriodKind> onPeriodChanged;
  final ValueChanged<String> onAnchorChanged;

  String get _today => toDateKey(DateTime.now());

  bool get _canGoNext => periodRange(period, shiftAnchor(period, anchor, 1)).from.compareTo(_today) <= 0;

  void _shift(int step) {
    final next = shiftAnchor(period, anchor, step);
    onAnchorChanged(next.compareTo(_today) > 0 ? _today : next);
  }

  String get _dateLabel {
    final date = parseDateKey(anchor);

    return switch (period) {
      'day' => DateFormat("d MMM y", 'es').format(date),
      'month' => capitalizeFirst(DateFormat('MMMM y', 'es').format(date)),
      _ => '${date.year}',
    };
  }

  Future<void> _pickDate(BuildContext context) async {
    final today = parseDateKey(_today);

    if (period == 'day') {
      final picked = await showDatePicker(
        context: context,
        initialDate: parseDateKey(anchor),
        firstDate: DateTime(today.year - 5),
        lastDate: today,
        helpText: 'Fecha',
      );
      if (picked != null) onAnchorChanged(toDateKey(picked));
      return;
    }

    if (period == 'month') {
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => _MonthPicker(anchor: anchor, today: _today),
      );
      if (picked != null) onAnchorChanged('$picked-01');
      return;
    }

    final current = DateTime.now().year;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final year in [current, current - 1])
              ListTile(
                title: Text('$year'),
                selected: parseDateKey(anchor).year == year,
                trailing: parseDateKey(anchor).year == year ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheetContext).pop(year),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onAnchorChanged('$picked-01-01');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<FinancePeriodKind>(
          showSelectedIcon: false,
          segments: [for (final option in _periods) ButtonSegment(value: option.value, label: Text(option.label))],
          selected: {period},
          onSelectionChanged: (selection) => onPeriodChanged(selection.first),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Período anterior',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shift(-1),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _pickDate(context),
                child: Semantics(
                  button: true,
                  label: 'Fecha',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: c.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(_dateLabel, style: AppFonts.label(fontSize: 14, color: c.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Período siguiente',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _canGoNext ? () => _shift(1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Elección de mes (equivale al `<input type="month">`), sin meses futuros.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.anchor, required this.today});

  final String anchor;
  final String today;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = parseDateKey(widget.anchor).year;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = parseDateKey(widget.today);
    final selected = widget.anchor.substring(0, 7);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Año anterior',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _year > today.year - 5 ? () => setState(() => _year--) : null,
                ),
                Text('$_year', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                IconButton(
                  tooltip: 'Año siguiente',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _year < today.year ? () => setState(() => _year++) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var month = 1; month <= 12; month++)
                  () {
                    final key = '$_year-${'$month'.padLeft(2, '0')}';
                    final isFuture = _year > today.year || (_year == today.year && month > today.month);
                    final isSelected = key == selected;

                    return Material(
                      color: isSelected ? c.primary : c.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isFuture ? null : () => Navigator.of(context).pop(key),
                        child: Center(
                          child: Text(
                            DateFormat('MMM', 'es').format(DateTime(_year, month)),
                            style: AppFonts.label(
                              fontSize: 14,
                              color: isSelected ? c.onPrimary : (isFuture ? c.outline : c.onSurface),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
