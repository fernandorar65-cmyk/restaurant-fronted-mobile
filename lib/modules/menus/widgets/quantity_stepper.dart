import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// "Agregar" cuando no hay unidades; con unidades, botones − cantidad +.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.quantity, required this.label, required this.onIncrease, required this.onDecrease});

  final int quantity;
  final String label;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (quantity == 0) {
      return Semantics(
        button: true,
        label: 'Agregar $label',
        excludeSemantics: true,
        child: Material(
          color: c.primary,
          shape: const StadiumBorder(),
          elevation: 1,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onIncrease,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: c.onPrimary),
                    const SizedBox(width: 6),
                    Text('Agregar', style: AppFonts.label(fontSize: 14, color: c.onPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundButton(
            icon: Icons.remove_rounded,
            tooltip: 'Quitar una unidad de $label',
            background: Colors.transparent,
            foreground: c.onPrimaryFixed,
            onTap: onDecrease,
          ),
          SizedBox(
            width: 28,
            child: Semantics(
              liveRegion: true,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: AppFonts.label(fontSize: 16, fontWeight: FontWeight.w700, color: c.onPrimaryFixed)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.add_rounded,
            tooltip: 'Agregar una unidad de $label',
            background: c.primary,
            foreground: c.onPrimary,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.background, required this.foreground, required this.onTap});

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 18, color: foreground)),
        ),
      ),
    );
  }
}
