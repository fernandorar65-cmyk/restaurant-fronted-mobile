import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../router/landing.dart';
import '../../router/routes.dart';
import '../../stores/diner_store.dart';
import '../../stores/session_store.dart';
import '../../stores/site_activity_store.dart';
import 'avatar.dart';

/// Menú de perfil del comensal: quién tiene sesión en este dispositivo
/// (un cliente, alguien del personal, ambos o nadie) y accesos rápidos.
class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final diner = context.watch<DinerStore>();
    final session = context.watch<SessionStore>();
    final name = diner.customer?.name ?? (session.isAuthenticated ? session.user?.name : null);

    return IconButton(
      tooltip: 'Perfil',
      icon: InitialsAvatar(name: name, size: 34),
      onPressed: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final diner = sheetContext.watch<DinerStore>();
        final session = sheetContext.watch<SessionStore>();
        final c = sheetContext.colors;
        final hasAny = diner.customer != null || session.isAuthenticated;
        final location = GoRouterState.of(context).uri.path;

        void go(String path) {
          Navigator.of(sheetContext).pop();
          context.go(path);
        }

        Widget section(String label) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(label.toUpperCase(), style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
            );

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasAny) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenido a RentaSol', style: AppFonts.headline(fontSize: 20, color: c.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          'Guarda tus pedidos y preferencias, o gestiona tu restaurante.',
                          style: TextStyle(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  ListTile(leading: const Icon(Icons.login_rounded), title: const Text('Iniciar sesión'), onTap: () => go(Routes.access)),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_rounded),
                    title: const Text('Crear cuenta'),
                    onTap: () => go('${Routes.access}?modo=registro'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('¿Tienes un restaurante?'),
                    subtitle: const Text('Súmalo a RentaSol'),
                    onTap: () => go(Routes.restaurantLanding),
                  ),
                ],
                if (diner.customer != null) ...[
                  section('Cliente'),
                  ListTile(
                    leading: InitialsAvatar(name: diner.customer!.name),
                    title: Text(diner.customer!.name),
                    subtitle: Text(diner.customer!.email),
                  ),
                  ListTile(leading: const Icon(Icons.person_outline_rounded), title: const Text('Mi perfil'), onTap: () => go(Routes.dinerProfile)),
                  ListTile(leading: const Icon(Icons.history_rounded), title: const Text('Mis visitas'), onTap: () => go(Routes.dinerVisits)),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Cerrar sesión de cliente'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      diner.setCustomer(null);
                      // Si estaba en una pantalla de su cuenta, vuelve al inicio.
                      if (location == Routes.dinerProfile || location == Routes.dinerVisits) {
                        context.go(Routes.home);
                      }
                    },
                  ),
                ],
                if (session.isAuthenticated) ...[
                  section('Restaurante'),
                  ListTile(leading: InitialsAvatar(name: session.user?.name), title: Text(session.user?.name ?? '')),
                  ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Mi perfil'), onTap: () => go(Routes.staffProfile)),
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: const Text('Ir al portal'),
                    onTap: () => go(landingRouteFor(session.user)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Cerrar sesión del portal'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.read<SiteActivityStore>().watchSite(null);
                      session.clearAuth();
                    },
                  ),
                ],
                if (hasAny && diner.customer == null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.login_rounded),
                    title: const Text('Ingresar como cliente'),
                    onTap: () => go(Routes.access),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
