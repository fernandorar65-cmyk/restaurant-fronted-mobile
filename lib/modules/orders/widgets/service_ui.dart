import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/base/base_button.dart';

/// Piezas de UI compartidas por las vistas de servicio (pedidos, cuentas, cocina, gastos).

/// Abre una hoja inferior con las mismas opciones que `showBaseDialog`, pero dejando que el
/// widget construya su propio `BaseDialogFrame` (cuando el pie depende del estado del contenido).
Future<T?> showServiceSheet<T>(BuildContext context, {required WidgetBuilder builder, bool isDismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: true,
    builder: builder,
  );
}

/// Cifras con ancho fijo (importes, contadores).
TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Aviso de error en línea (equivale a `<p role="alert" class="bg-error-container">`).
class InlineAlert extends StatelessWidget {
  const InlineAlert(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(10)),
        child: Text(message, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
      ),
    );
  }
}

/// Recuadro para pedir un motivo (rechazo, cancelación) con "Volver" y la acción destructiva.
class ReasonBox extends StatelessWidget {
  const ReasonBox({
    super.key,
    required this.controller,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.label,
    this.hint,
    this.busy = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.errorContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text(label!.toUpperCase(), style: AppFonts.label(fontSize: 11, color: c.onSurfaceVariant, letterSpacing: 0.6)),
            const SizedBox(height: 4),
          ],
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (value.text.trim().isNotEmpty) onConfirm();
                  },
                  decoration: InputDecoration(hintText: hint, isDense: true, filled: true, fillColor: c.surfaceContainerLowest),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BaseButton(label: 'Volver', variant: 'ghost', size: 'sm', onPressed: onCancel),
                    const SizedBox(width: 8),
                    BaseButton(
                      label: confirmLabel,
                      variant: 'danger',
                      size: 'sm',
                      loading: busy,
                      disabled: value.text.trim().isEmpty,
                      onPressed: onConfirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña tipo "pill".
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.background, required this.foreground, this.icon});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: foreground), const SizedBox(width: 4)],
          Text(label, style: tabular(AppFonts.label(fontSize: 12, color: foreground))),
        ],
      ),
    );
  }
}

/// Tarjeta de superficie con sombra suave.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor, this.onTap, this.color});

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(20);

    return Material(
      color: color ?? c.surfaceContainerLowest,
      borderRadius: radius,
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: borderColor == null ? null : Border.all(color: borderColor!, width: 2),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Color del anillo según la demora ('ok' | 'warning' | 'critical'); null = sin anillo.
Color? delayRingColor(BuildContext context, String level) => switch (level) {
  'critical' => context.colors.error,
  'warning' => context.colors.warning,
  _ => null,
};

Color delayTextColor(BuildContext context, String level) => switch (level) {
  'critical' => context.colors.error,
  'warning' => context.colors.warning,
  _ => context.colors.onSurfaceVariant,
};
