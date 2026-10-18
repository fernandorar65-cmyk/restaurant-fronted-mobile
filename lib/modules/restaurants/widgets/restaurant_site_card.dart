import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../types.dart';

/// Tarjeta de sede para el panel del personal (imagen, KPIs y "Entrar a sala de mando").
class RestaurantSiteCard extends StatelessWidget {
  const RestaurantSiteCard({super.key, required this.restaurant, required this.isSelected, required this.onEnter});

  final RestaurantSite restaurant;
  final bool isSelected;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color badgeBg, Color badgeFg) = switch (restaurant.badgeTone) {
      'amber' => (const Color(0xFFF59E0B), const Color(0xFF020617)),
      'emerald' => (c.success, c.onSuccess),
      'wine' => (const Color(0xFFB45309), Colors.white),
      'blue' => (const Color(0xFF2563EB), Colors.white),
      _ => (c.surfaceContainerHigh, c.onSurface),
    };
    final kpis = restaurant.kpis;

    Widget kpiBox({required String title, required String value, required Widget hint, required Widget footer}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: AppFonts.label(fontSize: 11, fontWeight: FontWeight.w700, color: c.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700, color: c.onSurface)),
                hint,
                const SizedBox(height: 4),
                footer,
              ],
            ),
          ),
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFF0F172A),
                  child: Image.network(
                    restaurant.imageUrl,
                    fit: BoxFit.cover,
                    semanticLabel: restaurant.name,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_outlined, size: 48, color: Colors.white54),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xB3000000), Color(0x33000000), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 90,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(restaurant.badgeLabel.toUpperCase(), style: AppFonts.label(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xCC022C22),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0x6610B981)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(restaurant.statusLabel, style: AppFonts.label(fontSize: 11, color: const Color(0xFF6EE7B7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      restaurant.code,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.cuisine.toUpperCase(), style: AppFonts.eyebrow(color: const Color(0xFFFCD34D))),
                      Text(restaurant.name, style: AppFonts.headline(fontSize: 24, color: Colors.white, height: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.6)))),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: c.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(restaurant.address, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
                      ),
                      Text(restaurant.capacityLabel, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: c.outline)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      kpiBox(
                        title: 'Facturación hoy',
                        value: kpis.revenueLabel,
                        hint: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: c.successContainer, borderRadius: BorderRadius.circular(4)),
                          child: Text(kpis.revenueHint, style: AppFonts.label(fontSize: 11, fontWeight: FontWeight.w700, color: c.onSuccessContainer)),
                        ),
                        footer: Text(kpis.marginLabel, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                      ),
                      const SizedBox(width: 10),
                      kpiBox(
                        title: 'Estado de stock',
                        value: kpis.stockLabel,
                        hint: Text(kpis.stockHint, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                        footer: Text(kpis.stockNote, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.success)),
                      ),
                      const SizedBox(width: 10),
                      kpiBox(
                        title: 'Aforo',
                        value: kpis.occupancyLabel,
                        hint: Text(kpis.occupancyHint, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                        footer: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (kpis.occupancyPercent / 100).clamp(0, 1).toDouble(),
                            minHeight: 6,
                            color: c.primary,
                            backgroundColor: c.surfaceContainerHigh,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.6)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                          children: [
                            const TextSpan(text: 'Rol: '),
                            TextSpan(text: restaurant.roleLabel, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: isSelected ? c.primary.withValues(alpha: 0.1) : c.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: isSelected ? BorderSide(color: c.primary) : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: onEnter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Center(
                              child: Text(
                                isSelected ? 'Sede activa' : 'Entrar a sala de mando',
                                style: AppFonts.label(fontSize: 13, color: isSelected ? c.primary : c.onPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
