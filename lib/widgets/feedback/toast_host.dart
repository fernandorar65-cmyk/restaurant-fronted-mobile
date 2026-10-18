import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../stores/toast_store.dart';

/// Pinta los avisos de [ToastStore] sobre toda la app.
/// En el portal van arriba; para el comensal, abajo, sobre la barra de navegación.
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.child, required this.isPortal});

  final Widget child;
  final bool Function() isPortal;

  @override
  Widget build(BuildContext context) {
    final toasts = context.watch<ToastStore>().toasts;
    final c = context.colors;
    final portal = isPortal();

    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          top: portal ? MediaQuery.of(context).padding.top + 64 : null,
          bottom: portal ? null : MediaQuery.of(context).padding.bottom + 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final toast in toasts)
                Padding(
                  key: ValueKey(toast.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ToastCard(toast: toast, colors: c),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.toast, required this.colors});

  final Toast toast;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final (Color background, Color foreground, IconData icon) = switch (toast.tone) {
      'success' => (c.success, c.onSuccess, Icons.check_circle_outline_rounded),
      'warning' => (c.warningContainer, c.onWarningContainer, Icons.notifications_active_outlined),
      'error' => (c.error, c.onError, Icons.error_outline_rounded),
      _ => (c.onSurface, c.surface, Icons.info_outline_rounded),
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 8 * (1 - value)), child: child)),
      child: Material(
        color: background,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.read<ToastStore>().dismiss(toast.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: foreground, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(toast.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: foreground)),
                        if (toast.message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(toast.message!, style: TextStyle(fontSize: 13, color: foreground.withValues(alpha: 0.9))),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
