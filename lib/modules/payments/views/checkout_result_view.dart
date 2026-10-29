import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../router/routes.dart';
import '../../../stores/checkout_store.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../checkout.dart';
import '../../../widgets/base/page_header.dart';

/// Pedido confirmado: comprobante del pago simulado.
class CheckoutResultView extends StatefulWidget {
  const CheckoutResultView({super.key});

  @override
  State<CheckoutResultView> createState() => _CheckoutResultViewState();
}

class _CheckoutResultViewState extends State<CheckoutResultView> {
  @override
  void initState() {
    super.initState();
    // Sin comprobante (por ejemplo, al reabrir la app) no hay nada que mostrar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<CheckoutStore>().lastReceipt == null) {
        context.go(Routes.home);
      }
    });
  }

  String _headline(CheckoutReceipt receipt) => switch (receipt.mode) {
        'pickup' => 'Te esperamos a las ${receipt.readyAt}',
        'delivery' => 'Llega hacia las ${receipt.readyAt}',
        _ => 'Estará listo hacia las ${receipt.readyAt}',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final receipt = context.watch<CheckoutStore>().lastReceipt;
    final diner = context.watch<DinerStore>();

    if (receipt == null) {
      return const SizedBox.shrink();
    }

    final divider = Divider(height: 1, thickness: 1, color: c.outlineVariant.withValues(alpha: 0.5));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: c.successContainer, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded, size: 40, color: c.success),
                ),
              ),
              const SizedBox(height: 12),
              const HeadingText('¡Pedido ', accent: 'confirmado!', fontSize: 30, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_headline(receipt), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: c.onSurfaceVariant)),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    'Pedido ${receipt.code}',
                    style: AppFonts.label(fontSize: 14, fontWeight: FontWeight.w700, color: c.onSurface, letterSpacing: 2.4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
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
                        children: [
                          Text(
                            '${receipt.restaurantName} · ${fulfillmentLabel[receipt.mode] ?? ''}',
                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          ),
                          Text(receipt.fulfillmentDetail, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                        ],
                      ),
                    ),
                    divider,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        spacing: 4,
                        children: [
                          for (final item in receipt.items)
                            _ItemRow(
                              label: '${item.quantity} × ${item.name}',
                              value: formatMoney(item.price * item.quantity, receipt.currency),
                            ),
                          if (receipt.deliveryFee > 0) _ItemRow(label: 'Envío', value: formatMoney(receipt.deliveryFee, receipt.currency)),
                        ],
                      ),
                    ),
                    divider,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface))),
                          Text(formatMoney(receipt.total, receipt.currency), style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
                        ],
                      ),
                    ),
                    divider,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pago · ${receipt.methodLabel}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                          Text(receipt.paymentDetail, style: TextStyle(fontSize: 14, color: c.onSurface)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Vista de demostración: no se realizó ningún cobro y el pedido todavía no llega al restaurante. '
                  'Se conectará con el sistema de pagos y el backend más adelante.',
                  style: TextStyle(fontSize: 12, color: c.onWarningContainer),
                ),
              ),
              const SizedBox(height: 20),
              BaseButton(
                label: 'Volver a la carta',
                variant: 'primary',
                size: 'lg',
                block: true,
                onPressed: () => context.go(diner.menuRoute),
              ),
              const SizedBox(height: 8),
              BaseButton(label: 'Ir al inicio', size: 'lg', block: true, onPressed: () => context.go(Routes.home)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.onSurface)),
        ),
        const SizedBox(width: 12),
        Text(value, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
      ],
    );
  }
}
