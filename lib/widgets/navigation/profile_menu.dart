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

enum _MenuAccount { customer, staff }

/// Solo un tipo de cuenta a la vez. Si hay sesión de cliente y de personal,
/// en el área del comensal manda la del cliente.
_MenuAccount? _accountFor(DinerStore diner, SessionStore session) {
  if (diner.customer != null) return _MenuAccount.customer;
  return session.isAuthenticated ? _MenuAccount.staff : null;
}

/// Menú de perfil del comensal: muestra una sola cuenta (la del cliente o, si no hay,
/// la del personal) con sus accesos rápidos, o la bienvenida si no hay sesión.
class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final diner = context.watch<DinerStore>();
    final session = context.watch<SessionStore>();
    final name = switch (_accountFor(diner, session)) {
      _MenuAccount.customer => diner.customer?.name,
      _MenuAccount.staff => session.user?.name,
      null => null,
    };

    return IconButton(
      tooltip: 'Perfil',
      icon: InitialsAvatar(name: name, size: 34),
      onPressed: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    // Se leen antes de abrir: la hoja puede reconstruirse cuando la pantalla de atrás ya no está activa.
    final router = GoRouter.of(context);
    final location = GoRouterState.of(context).uri.path;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final diner = sheetContext.watch<DinerStore>();
        final session = sheetContext.watch<SessionStore>();
        final c = sheetContext.colors;
        final account = _accountFor(diner, session);
        void go(String path) {
          Navigator.of(sheetContext).pop();
          router.go(path);
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
                if (account == null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenido a RentaSol', style: AppFonts.title(fontSize: 20, color: c.heading)),
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
                if (account == _MenuAccount.customer) ...[
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
                        router.go(Routes.home);
                      }
                    },
                  ),
                ],
                if (account == _MenuAccount.staff) ...[
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
