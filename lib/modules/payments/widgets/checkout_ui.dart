import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Piezas visuales comunes a las pantallas del checkout del comensal.

/// Ícono de cada método de pago del checkout (la web usa trazos heroicons).
IconData checkoutMethodIcon(String method) => switch (method) {
      'card' => Icons.credit_card_rounded,
      'yape' || 'plin' => Icons.smartphone_rounded,
      'transfer' => Icons.account_balance_outlined,
      'cash' => Icons.payments_outlined,
      _ => Icons.payment_rounded,
    };

/// 5.0 → "5", 2.5 → "2.5" (como imprime los números la web).
String formatPlainNumber(num value) => value == value.roundToDouble() ? value.round().toString() : value.toString();

/// Tarjeta blanca con borde suave (`rounded-2xl bg-surface-container-lowest ring-1`).
class CheckoutSection extends StatelessWidget {
  const CheckoutSection({super.key, required this.children, this.padding = const EdgeInsets.all(16), this.spacing = 12});

  final List<Widget> children;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(height: spacing),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Título de sección (`font-headline text-lg`).
class CheckoutSectionTitle extends StatelessWidget {
  const CheckoutSectionTitle(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
        if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
      ],
    );
  }
}

/// Etiqueta pequeña sobre un campo, con el campo debajo y el error opcional.
class CheckoutField extends StatelessWidget {
  const CheckoutField({super.key, required this.label, required this.child, this.error});

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurfaceVariant)),
        const SizedBox(height: 4),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: TextStyle(fontSize: 12, color: c.error)),
        ],
      ],
    );
  }
}

/// Decoración de los inputs del checkout (`min-h-12 rounded-xl bg-surface`).
InputDecoration checkoutInputDecoration(BuildContext context, {String? hint, Widget? suffix}) {
  final c = context.colors;

  return InputDecoration(
    hintText: hint,
    fillColor: c.surface,
    constraints: const BoxConstraints(minHeight: 48),
    suffixIcon: suffix,
  );
}

/// Encabezado de pantalla del checkout (`font-headline text-3xl` + bajada).
class CheckoutTitle extends StatelessWidget {
  const CheckoutTitle({super.key, required this.title, this.subtitle, this.leading});

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?leading,
        Text(title, style: AppFonts.title(fontSize: 28, color: c.heading, height: 1.2)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Barra inferior fija con la acción principal (la web la deja `sticky bottom`).
class CheckoutActionBar extends StatelessWidget {
  const CheckoutActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3))),
        boxShadow: const [BoxShadow(color: Color(0x141B1C1D), blurRadius: 24, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Aviso de error dentro de un formulario (`bg-error-container`).
class CheckoutAlert extends StatelessWidget {
  const CheckoutAlert(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
      ),
    );
  }
}

/// Fila "concepto ··· importe" de un resumen.
class CheckoutAmountRow extends StatelessWidget {
  const CheckoutAmountRow({super.key, required this.label, required this.value, this.total = false});

  final String label;
  final String value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (total) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface))),
            Text(value, style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))),
          Text(value, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}
