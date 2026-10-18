import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Diálogo único de la app (equivale a BaseDialog.vue): en móvil, hoja que sube desde abajo.
///
/// ```dart
/// final saved = await showBaseDialog<bool>(
///   context,
///   title: 'Nueva mesa',
///   builder: (context) => TableForm(...),
/// );
/// ```
/// Para un pie fijo con botones, pasar [footerBuilder]. Cerrar con `Navigator.pop(context, value)`.
Future<T?> showBaseDialog<T>(
  BuildContext context, {
  required String title,
  String? eyebrow,
  String? subtitle,
  required WidgetBuilder builder,
  WidgetBuilder? footerBuilder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: true,
    builder: (sheetContext) => BaseDialogFrame(
      title: title,
      eyebrow: eyebrow,
      subtitle: subtitle,
      footer: footerBuilder?.call(sheetContext),
      child: builder(sheetContext),
    ),
  );
}

/// Marco de la hoja: encabezado, contenido desplazable y pie opcional.
class BaseDialogFrame extends StatelessWidget {
  const BaseDialogFrame({super.key, required this.title, this.eyebrow, this.subtitle, this.footer, required this.child});

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? footer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) Text(eyebrow!.toUpperCase(), style: AppFonts.eyebrow(color: c.tertiary)),
                        Text(title, style: AppFonts.headline(fontSize: 22, color: c.onSurface, height: 1.2)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: Icon(Icons.close_rounded, color: c.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: child,
              ),
            ),
            if (footer != null)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)))),
                child: SafeArea(
                  top: false,
                  child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), child: footer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
