import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../stores/cart_store.dart';
import '../../../widgets/base/base_dialog.dart';
import '../types.dart';
import 'menu_product_card.dart';
import 'quantity_stepper.dart';

/// Detalle de un producto de la carta (hoja inferior). La cantidad se lee del carrito en vivo.
Future<void> showMenuProductDetailDialog(
  BuildContext context, {
  required MenuProduct product,
  required String currency,
  required bool orderable,
  required VoidCallback onIncrease,
  required VoidCallback onDecrease,
}) {
  return showBaseDialog<void>(
    context,
    title: product.name,
    builder: (context) => MenuProductDetailDialog(product: product),
    footerBuilder: (context) => _DetailFooter(
      product: product,
      currency: currency,
      orderable: orderable,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
    ),
  );
}

/// Contenido del detalle: imagen, etiquetas, descripción, ingredientes, presentación y alérgenos.
class MenuProductDetailDialog extends StatelessWidget {
  const MenuProductDetailDialog({super.key, required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final description = product.longDescription.isNotEmpty ? product.longDescription : product.description;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text.toUpperCase(), style: AppFonts.eyebrow(color: c.outline)),
        );

    Widget pill(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c.onSurface),
              const SizedBox(width: 6),
              Text(text, style: AppFonts.label(fontSize: 12, color: c.onSurface)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MenuProductImage(url: product.imageUrl, radius: 16),
              if (product.portion.isNotEmpty || (product.prepMinutes ?? 0) > 0)
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((product.prepMinutes ?? 0) > 0)
                        Semantics(
                          label: 'Tiempo de preparación: ${product.prepMinutes} min',
                          excludeSemantics: true,
                          child: pill(Icons.schedule_rounded, '${product.prepMinutes} min'),
                        ),
                      if (product.portion.isNotEmpty) pill(Icons.people_outline_rounded, product.portion),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (product.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in product.tags) MenuTagChip(tag: tag, large: true)]),
        ],
        const SizedBox(height: 16),
        Text(description, style: TextStyle(fontSize: 16, height: 1.5, color: c.onSurface)),
        if (product.ingredients.isNotEmpty) ...[
          const SizedBox(height: 20),
          sectionTitle('Ingredientes'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ingredient in product.ingredients)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Text(ingredient, style: TextStyle(fontSize: 14, color: c.onSurface)),
                ),
            ],
          ),
        ],
        if (product.presentation.isNotEmpty) ...[
          const SizedBox(height: 20),
          sectionTitle('Presentación'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.room_service_outlined, size: 20, color: c.primaryInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(product.presentation, style: TextStyle(fontSize: 14, height: 1.5, color: c.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
        if (product.allergens.isNotEmpty) ...[
          const SizedBox(height: 20),
          sectionTitle('Alérgenos'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'Contiene '),
                      TextSpan(
                        text: product.allergens.join(', '),
                        style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DetailFooter extends StatelessWidget {
  const _DetailFooter({
    required this.product,
    required this.currency,
    required this.orderable,
    required this.onIncrease,
    required this.onDecrease,
  });

  final MenuProduct product;
  final String currency;
  final bool orderable;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quantity = context.watch<CartStore>().quantityOf(product.id);
    final priceStyle = AppFonts.headline(fontSize: 20, color: c.onSurface);

    if (!product.isAvailable) {
      return Row(
        children: [
          Expanded(child: Text(formatMoney(product.price, currency), style: priceStyle)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999)),
            child: Text('Agotado', style: AppFonts.label(fontSize: 14, color: c.onSurfaceVariant)),
          ),
        ],
      );
    }

    if (orderable && quantity == 0) {
      return Material(
        color: c.primary,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onIncrease,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, color: c.onPrimary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Agregar a la orden', style: AppFonts.label(fontSize: 16, color: c.onPrimary))),
                  Text(formatMoney(product.price, currency), style: AppFonts.label(fontSize: 16, color: c.onPrimary)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (orderable) {
      return Row(
        children: [
          QuantityStepper(quantity: quantity, label: product.name, onIncrease: onIncrease, onDecrease: onDecrease),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('En tu orden', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
              Text(formatMoney(product.price * quantity, currency), style: priceStyle),
            ],
          ),
        ],
      );
    }

    return Text(formatMoney(product.price, currency), style: priceStyle);
  }
}
