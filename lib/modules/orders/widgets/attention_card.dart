import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../widgets/base/status_badge.dart';
import '../order_status_labels.dart';
import '../types.dart';
import 'service_ui.dart';

/// Resumen de una atención (mesa) en la lista de pedidos.
class AttentionCard extends StatelessWidget {
  const AttentionCard({super.key, required this.attention, required this.currency, required this.onSelect});

  final AttentionWithProducts attention;
  final String currency;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final billable = attention.products.where((product) => isBillableProduct(product.status)).toList();
    final subtotal = billable.fold<double>(0, (sum, product) => sum + product.subtotal);
    final pendingCount = billable.where((product) => product.status == 'sent').length;
    final readyCount = billable.where((product) => product.status == 'ready').length;
    final summary = billable.map((product) => '${product.quantity}× ${product.name}').join(', ');

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onSelect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mesa ${attention.tableNumber}',
                  style: AppFonts.headline(fontSize: 15, fontWeight: FontWeight.w700, color: c.onSurface),
                ),
              ),
              StatusBadge(
                tone: attentionStatusTone[attention.status] ?? 'neutral',
                label: attentionStatusLabel[attention.status] ?? attention.status,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary.isEmpty ? 'Sin productos' : summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (pendingCount > 0) Text('$pendingCount sin confirmar', style: AppFonts.label(fontSize: 13, color: c.error)),
              if (pendingCount > 0 && readyCount > 0) const SizedBox(width: 8),
              if (readyCount > 0) Text('$readyCount listos', style: AppFonts.label(fontSize: 13, color: c.success)),
              if (pendingCount == 0 && readyCount == 0)
                Text('${billable.length} productos', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
              const Spacer(),
              Text(
                formatMoney(subtotal, currency),
                style: tabular(AppFonts.label(fontSize: 14, fontWeight: FontWeight.w700, color: c.primaryInk)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
