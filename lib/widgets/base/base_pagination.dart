import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Paginado de listas: rango mostrado, tamaño de página y navegación por números.
class BasePagination extends StatelessWidget {
  const BasePagination({
    super.key,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [15, 30, 50],
    this.itemLabel = 'registros',
  });

  final int total;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizeOptions;

  /// Sustantivo en plural para el resumen, ej. "gastos".
  final String itemLabel;

  int get pageCount => max(1, (total / pageSize).ceil());

  /// Números a mostrar: primera, última y las vecinas de la actual; null = "…".
  List<int?> get pages {
    final count = pageCount;

    if (count <= 7) {
      return List.generate(count, (index) => index + 1);
    }

    final set = <int>{1, count, page - 1, page, page + 1};
    if (page <= 3) set.addAll([2, 3, 4]);
    if (page >= count - 2) set.addAll([count - 3, count - 2, count - 1]);
    final sorted = set.where((value) => value >= 1 && value <= count).toList()..sort();
    final result = <int?>[];

    for (var index = 0; index < sorted.length; index++) {
      if (index > 0 && sorted[index] - sorted[index - 1] > 1) result.add(null);
      result.add(sorted[index]);
    }

    return result;
  }

  void _go(int target) => onPageChanged(min(pageCount, max(1, target)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = min(total, page * pageSize);

    Widget navButton({required Widget child, required VoidCallback? onTap, bool active = false}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: active ? c.primary : null, borderRadius: BorderRadius.circular(8)),
            child: DefaultTextStyle.merge(
              style: AppFonts.label(fontSize: 14, color: active ? c.onPrimary : c.onSurfaceVariant),
              child: Opacity(opacity: onTap == null && !active ? 0.3 : 1, child: child),
            ),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$from–$to de $total $itemLabel', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: pageSize,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: [for (final size in pageSizeOptions) DropdownMenuItem(value: size, child: Text('$size'))],
              onChanged: (size) {
                if (size == null) return;
                // Se mantiene a la vista el primer elemento de la página actual.
                final firstIndex = (page - 1) * pageSize;
                onPageSizeChanged(size);
                onPageChanged(firstIndex ~/ size + 1);
              },
            ),
          ],
        ),
        if (pageCount > 1)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              navButton(child: const Icon(Icons.chevron_left_rounded, size: 18), onTap: page <= 1 ? null : () => _go(page - 1)),
              for (final value in pages)
                value == null
                    ? Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: TextStyle(color: c.outline)))
                    : navButton(child: Text('$value'), active: value == page, onTap: () => _go(value)),
              navButton(child: const Icon(Icons.chevron_right_rounded, size: 18), onTap: page >= pageCount ? null : () => _go(page + 1)),
            ],
          ),
      ],
    );
  }
}
