import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 'primary' | 'secondary' | 'ghost' | 'danger' | 'danger-soft' | 'success' | 'dark'
typedef ButtonVariant = String;

/// 'sm' | 'md' | 'lg'
typedef ButtonSize = String;

/// Botón de la app (equivale a BaseButton.vue). Con [to] navega con `context.push`.
class BaseButton extends StatelessWidget {
  const BaseButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = 'secondary',
    this.size = 'md',
    this.icon,
    this.to,
    this.block = false,
    this.disabled = false,
    this.loading = false,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Ruta a la que navega al tocarlo (en lugar de [onPressed]).
  final String? to;
  final bool block;
  final bool disabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color background, Color foreground) = switch (variant) {
      'primary' => (c.primary, c.onPrimary),
      'ghost' => (Colors.transparent, c.onSurfaceVariant),
      'danger' => (c.error, c.onError),
      'danger-soft' => (c.errorContainer, c.onErrorContainer),
      'success' => (c.success, c.onSuccess),
      'dark' => (c.onSurface, c.surface),
      _ => (c.surfaceContainer, c.onSurface),
    };
    final (double height, double padding, double fontSize, double radius) = switch (size) {
      'sm' => (36.0, 12.0, 13.0, 8.0),
      'lg' => (48.0, 20.0, 16.0, 12.0),
      _ => (44.0, 16.0, 14.0, 12.0),
    };
    final isDisabled = disabled || loading || (onPressed == null && to == null);

    final child = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground)),
          )
        else if (icon != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: Icon(icon, size: fontSize + 4, color: foreground)),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.label(fontSize: fontSize, color: foreground),
          ),
        ),
        if (trailingIcon != null)
          Padding(padding: const EdgeInsets.only(left: 8), child: Icon(trailingIcon, size: fontSize + 4, color: foreground)),
      ],
    );

    final button = Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        elevation: variant == 'primary' ? 1 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: isDisabled
              ? null
              : () {
                  if (to != null) {
                    context.push(to!);
                  } else {
                    onPressed?.call();
                  }
                },
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6), child: Center(widthFactor: 1, child: child)),
          ),
        ),
      ),
    );

    return block ? SizedBox(width: double.infinity, child: button) : button;
  }
}
