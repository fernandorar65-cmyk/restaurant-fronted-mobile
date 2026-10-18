import 'package:flutter/material.dart';

import '../../../core/http/http_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/base/base_button.dart';

/// Piezas comunes de las vistas y formularios de Administración.

/// Aviso de error en línea (equivale al `<p role="alert">` de las vistas web).
class InlineAlert extends StatelessWidget {
  const InlineAlert(this.message, {super.key, this.tone = 'error'});

  final String message;

  /// 'error' | 'success'
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final success = tone == 'success';

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: success ? c.successContainer : c.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              size: 18,
              color: success ? c.onSuccessContainer : c.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: success ? FontWeight.w600 : FontWeight.w400,
                  color: success ? c.onSuccessContainer : c.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta blanca con sombra suave (rounded-2xl bg-surface-container-lowest shadow-sm).
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.dimmed = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Material(
      color: c.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: card,
      ),
    );
  }
}

/// Etiqueta corta en mayúsculas sobre un grupo de controles.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: AppFonts.eyebrow(color: context.colors.onSurfaceVariant, fontSize: 11)),
      );
}

/// Pie de los formularios: Cancelar + acción principal.
class DialogActions extends StatelessWidget {
  const DialogActions({super.key, required this.onSubmit, this.submitLabel = 'Guardar', this.loading = false});

  final VoidCallback onSubmit;
  final String submitLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BaseButton(label: 'Cancelar', block: true, onPressed: () => Navigator.of(context).maybePop()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BaseButton(label: submitLabel, variant: 'primary', block: true, loading: loading, onPressed: onSubmit),
        ),
      ],
    );
  }
}

/// Espacio vertical estándar entre campos.
const Widget fieldGap = SizedBox(height: 14);

/// Fila de dos campos que se apila en pantallas muy angostas.
class FieldPair extends StatelessWidget {
  const FieldPair({super.key, required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(children: [first, fieldGap, second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)],
        );
      },
    );
  }
}

/// Tarjeta de indicador simple (etiqueta en mayúsculas + número grande).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.hint, this.valueColor});

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppFonts.eyebrow(color: c.onSurfaceVariant, fontSize: 10.5), maxLines: 2),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.headline(fontSize: 28, color: valueColor ?? c.onSurface)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Rejilla de 2 columnas para indicadores (altura según el contenido).
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var index = 0; index < children.length; index += 2) {
      final hasSecond = index + 1 < children.length;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[index]),
              SizedBox(width: spacing),
              Expanded(child: hasSecond ? children[index + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
      if (index + 2 < children.length) rows.add(SizedBox(height: spacing));
    }

    return Column(children: rows);
  }
}

/// Mensaje de un error de carga: el del API si es un HttpError, si no el genérico.
String errorText(Object error, String fallback) => error is HttpError ? error.message : fallback;
