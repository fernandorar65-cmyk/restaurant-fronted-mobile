import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../types.dart';
import 'quantity_stepper.dart';

const String chefTag = 'Recomendado chef';

/// Imagen de producto con respaldo cuando no carga.
class MenuProductImage extends StatelessWidget {
  const MenuProductImage({super.key, required this.url, this.width, this.height, this.radius = 12});

  final String url;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = Container(
      width: width,
      height: height,
      color: c.surfaceContainer,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant_rounded, color: c.outline),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }
}

/// Etiqueta de producto ("Recomendado chef" destacada).
class MenuTagChip extends StatelessWidget {
  const MenuTagChip({super.key, required this.tag, this.large = false});

  final String tag;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isChef = tag == chefTag;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: isChef ? c.tertiaryFixed.withValues(alpha: 0.6) : c.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isChef) ...[Icon(Icons.star_rounded, size: 12, color: c.onTertiaryContainer), const SizedBox(width: 4)],
          Text(tag, style: AppFonts.label(fontSize: large ? 12 : 11, color: isChef ? c.onTertiaryContainer : c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Tarjeta de producto de la carta del comensal.
class MenuProductCard extends StatelessWidget {
  const MenuProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.currency,
    required this.orderable,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDetail,
  });

  final MenuProduct product;
  final int quantity;
  final String currency;

  /// false = carta de otra sede (el comensal tiene mesa en una distinta): no se puede agregar a la orden.
  final bool orderable;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Opacity(
      opacity: product.isAvailable ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onDetail,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: AppFonts.headline(fontSize: 17, color: c.onSurface, height: 1.3)),
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, height: 1.45, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (product.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 4, runSpacing: 4, children: [for (final tag in product.tags) MenuTagChip(tag: tag)]),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatMoney(product.price, currency),
                            style: AppFonts.label(fontSize: 16, fontWeight: FontWeight.w700, color: c.onSurface),
                          ),
                        ),
                        if (orderable && product.isAvailable)
                          QuantityStepper(quantity: quantity, label: product.name, onIncrease: onIncrease, onDecrease: onDecrease),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Ver detalle de ${product.name}',
              child: GestureDetector(
                onTap: onDetail,
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MenuProductImage(url: product.imageUrl, width: 112, height: 112),
                      if (!product.isAvailable)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            child: Container(
                              color: c.onSurface.withValues(alpha: 0.8),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Agotado',
                                textAlign: TextAlign.center,
                                style: AppFonts.label(fontSize: 12, color: c.surface),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
