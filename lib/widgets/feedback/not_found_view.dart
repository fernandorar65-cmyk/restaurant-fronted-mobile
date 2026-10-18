import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../router/landing.dart';
import '../../router/routes.dart';
import '../../stores/session_store.dart';
import '../base/base_button.dart';

class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final c = context.colors;
    // El personal vuelve a su inicio según rol; el comensal, a la selección de sede.
    final homeRoute = session.isAuthenticated ? landingRouteFor(session.user) : Routes.home;
    final homeLabel = session.isAuthenticated ? 'Ir a mi inicio' : 'Ver restaurantes';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('404', style: AppFonts.headline(fontSize: 72, color: c.primary)),
                Text('ERROR 404', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
                const SizedBox(height: 12),
                Text('Página no encontrada', style: AppFonts.headline(fontSize: 22, color: c.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'La dirección que buscas no existe o cambió.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  children: [
                    if (context.canPop()) BaseButton(label: 'Volver', onPressed: () => context.pop()),
                    BaseButton(label: homeLabel, variant: 'primary', onPressed: () => context.go(homeRoute)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
