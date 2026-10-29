import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../types.dart';
import 'menu_product_card.dart';

/// Vista previa de la carta tal como la vería el comensal: solo productos activos
/// y categorías con productos.
class MenuPreviewDialog extends StatelessWidget {
  const MenuPreviewDialog({super.key, required this.menuName, required this.categories, required this.products, required this.currency});

  final String menuName;
  final List<MenuCategory> categories;
  final List<MenuProduct> products;
  final String currency;

  static Future<void> show(
    BuildContext context, {
    required String menuName,
    required List<MenuCategory> categories,
    required List<MenuProduct> products,
    required String currency,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MenuPreviewDialog(menuName: menuName, categories: categories, products: products, currency: currency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = [
      for (final category in categories)
        (category, products.where((product) => product.categoryId == category.id && product.isActive).toList()),
    ].where((group) => group.$2.isNotEmpty).toList();

    return Semantics(
      label: 'Vista previa de la carta',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VISTA DEL COMENSAL', style: AppFonts.eyebrow(color: c.primaryInk)),
                        Text(menuName, style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cerrar')),
                ],
              ),
            ),
            Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
            Flexible(
              child: Container(
                color: c.background,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (groups.isEmpty)
                      Text('Este menú no tiene productos activos.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 4),
                        child: Text(group.$1.name, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                      ),
                      for (final product in group.$2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MenuProductCard(
                            product: product,
                            quantity: 0,
                            currency: currency,
                            orderable: false,
                            onIncrease: () {},
                            onDecrease: () {},
                            onDetail: () {},
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
