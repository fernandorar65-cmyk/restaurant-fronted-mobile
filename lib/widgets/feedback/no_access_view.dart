import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../router/landing.dart';
import '../../stores/session_store.dart';
import '../base/base_button.dart';

class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, this.reason});

  /// `?motivo=sede` | `?motivo=permiso`
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final c = context.colors;
    final hasRole = (session.user?.permissions.length ?? 0) > 0;
    final message = !hasRole
        ? 'Tu cuenta todavía no tiene un rol asignado. Pide a un administrador que te asigne uno desde Administración → Usuarios.'
        : reason == 'sede'
            ? 'Tu cuenta no tiene acceso a esta sede.'
            : 'Tu rol no tiene permiso para abrir esta sección.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.lock_outline_rounded, color: c.onSurfaceVariant, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Sin acceso', style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            if (session.user?.roleName != null) ...[
              const SizedBox(height: 8),
              Text('Rol actual: ${session.user!.roleName}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            ],
            if (hasRole) ...[
              const SizedBox(height: 16),
              BaseButton(label: 'Ir a mi inicio', variant: 'primary', onPressed: () => context.go(landingRouteFor(session.user))),
            ],
          ],
        ),
      ),
    );
  }
}
