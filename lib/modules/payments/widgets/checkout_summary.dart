import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../stores/cart_store.dart';
import '../../../stores/checkout_store.dart';
import '../../../stores/diner_store.dart';
import '../checkout.dart';
import 'checkout_ui.dart';

/// Resumen del checkout: sede, cómo se recibe el pedido y total.
/// [trailing] ocupa el lugar del slot de la web (p. ej. el enlace "Cambiar").
class CheckoutSummary extends StatelessWidget {
  const CheckoutSummary({super.key, required this.total, required this.deliveryFee, this.trailing});

  final double total;
  final double deliveryFee;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cart = context.watch<CartStore>();
    final diner = context.watch<DinerStore>();
    final checkout = context.watch<CheckoutStore>();
    final mode = checkout.mode;

    final fulfillmentDetail = switch (mode) {
      'dine-in' => 'Mesa ${diner.tableCode ?? '—'}',
      'pickup' => 'Llegada ${checkout.pickup.arrivalTime} · ${checkout.pickup.eatIn ? 'Come en el local' : 'Para llevar'}',
      'delivery' => checkout.delivery.address,
      _ => '—',
    };
    final divider = Divider(height: 1, thickness: 1, color: c.outlineVariant.withValues(alpha: 0.5));

    Widget caption(String text) => Text(text, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant));
    Widget value(String text) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
        );

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [caption('Sede'), value(diner.restaurantName ?? '')],
            ),
          ),
          divider,
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      caption(mode != null ? (fulfillmentLabel[mode] ?? 'Entrega') : 'Entrega'),
                      value(fulfillmentDetail),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
          divider,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                CheckoutAmountRow(
                  label: '${cart.itemCount} ${cart.itemCount == 1 ? 'producto' : 'productos'}',
                  value: formatMoney(cart.subtotal, diner.currency),
                ),
                if (deliveryFee > 0) CheckoutAmountRow(label: 'Envío', value: formatMoney(deliveryFee, diner.currency)),
                CheckoutAmountRow(label: 'Total', value: formatMoney(total, diner.currency), total: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
