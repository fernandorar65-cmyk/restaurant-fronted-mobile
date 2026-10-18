import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/features.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../modules/auth/permissions.dart';
import '../router/landing.dart';
import '../router/routes.dart';
import '../router/site_directory.dart';
import '../stores/session_store.dart';
import '../stores/site_activity_store.dart';
import '../stores/toast_store.dart';
import '../widgets/navigation/avatar.dart';
import '../widgets/navigation/theme_menu.dart';

final RegExp _siteSlugPattern = RegExp(r'^/owner/sede/([^/]+)');

/// Slug de la sede abierta en el portal (/owner/sede/:siteSlug), o null fuera de una sede.
String? currentSiteSlug(GoRouterState state) => _siteSlugPattern.firstMatch(state.uri.path)?.group(1);

/// Layout del portal del restaurante: barra superior, menú lateral (drawer) y contenido.
/// Vigila la actividad de la sede abierta y relee el acceso del usuario al navegar.
class PortalShell extends StatefulWidget {
  const PortalShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  String? _lastPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onRoute();
  }

  @override
  void didUpdateWidget(covariant PortalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onRoute();
  }

  @override
  void dispose() {
    // El widget puede desmontarse con el árbol ya inactivo: se difiere al siguiente frame.
    final activity = context.read<SiteActivityStore>();
    WidgetsBinding.instance.addPostFrameCallback((_) => activity.watchSite(null));
    super.dispose();
  }

  void _onRoute() {
    final path = widget.state.uri.toString();

    if (path == _lastPath) {
      return;
    }

    _lastPath = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _watchSite();
      _syncAccess();
    });
  }

  Future<void> _watchSite() async {
    final slug = currentSiteSlug(widget.state);
    final activity = context.read<SiteActivityStore>();

    if (slug == null) {
      activity.watchSite(null);
      return;
    }

    await SiteDirectory.ensure().catchError((_) {});
    activity.watchSite(SiteDirectory.idFor(slug));
  }

  /// Relee rol y permisos: aplica cambios hechos por un administrador y expulsa cuentas bloqueadas.
  Future<void> _syncAccess() async {
    final session = context.read<SessionStore>();
    final activity = context.read<SiteActivityStore>();
    final toast = context.read<ToastStore>();
    final router = GoRouter.of(context);

    try {
      final stillValid = await session.refreshUser();

      if (!stillValid) {
        activity.watchSite(null);
        toast.show('Tu sesión se cerró', message: 'La cuenta fue bloqueada o desactivada.', tone: 'error');
        router.go(Routes.login);
      }
    } catch (_) {
      // Sin conexión: se mantiene la sesión local hasta el próximo intento.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final c = context.colors;
    final slug = currentSiteSlug(widget.state);
    final site = slug == null ? null : SiteDirectory.lookup(slug);
    final canSwitchSite = session.hasSiteAccess && (session.user?.restaurantIds.length ?? 0) != 1;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => context.go(landingRouteFor(session.user)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurant-CMR', style: AppFonts.headline(fontSize: 17, color: c.onSurface)),
              if (site != null)
                Row(
                  children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        canSwitchSite ? '${site.name} · Cambiar' : site.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                      ),
                    ),
                  ],
                )
              else
                Text('Portal del restaurante', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            ],
          ),
        ),
        actions: [
          const ThemeMenu(),
          if (session.user != null)
            IconButton(
              tooltip: 'Mi cuenta',
              icon: InitialsAvatar(name: session.user!.name, size: 34),
              onPressed: () => _openAccountMenu(context),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      drawer: PortalDrawer(state: widget.state),
      body: widget.child,
    );
  }

  /// Avatar del portal del restaurante: abre "Mi perfil" y "Cerrar sesión".
  void _openAccountMenu(BuildContext context) {
    final session = context.read<SessionStore>();
    final user = session.user!;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: InitialsAvatar(name: user.name),
              title: Text(user.name),
              subtitle: Text(user.roleName ?? user.email),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(Routes.staffProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Cerrar sesión'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.read<SiteActivityStore>().watchSite(null);
                session.clearAuth();
                context.go(Routes.login);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SiteNavItem {
  const _SiteNavItem({required this.group, required this.path, required this.label, required this.permission, required this.icon, this.badge, this.extraMatch});

  /// 'service' | 'site' | 'reports'
  final String group;
  final String Function(String slug) path;
  final String label;
  final Permission permission;
  final IconData icon;

  /// 'incoming' | 'kitchen' | 'ready' | 'accountRequested'
  final String? badge;

  /// Rutas de detalle que también marcan la opción como activa.
  final RegExp? extraMatch;
}

final List<_SiteNavItem> _siteItems = [
  _SiteNavItem(
    group: 'service',
    path: Routes.siteOrders,
    label: 'Gestión de pedidos',
    permission: Permissions.ordersManage,
    icon: Icons.assignment_outlined,
    badge: 'incoming',
    extraMatch: RegExp(r'/pedidos/[^/]+$'),
  ),
  _SiteNavItem(group: 'service', path: Routes.siteDashboard, label: 'Gestión de mesas', permission: Permissions.sitesManage, icon: Icons.grid_view_rounded),
  if (Features.kitchenQueue)
    _SiteNavItem(
      group: 'service',
      path: Routes.siteKitchen,
      label: 'Cocina',
      permission: Permissions.kitchenManage,
      icon: Icons.local_fire_department_outlined,
      badge: 'kitchen',
    ),
  _SiteNavItem(
    group: 'service',
    path: Routes.siteAccounts,
    label: 'Cuentas',
    permission: Permissions.paymentsManage,
    icon: Icons.credit_card_outlined,
    badge: 'accountRequested',
    extraMatch: RegExp(r'/cuentas/[^/]+$'),
  ),
  _SiteNavItem(group: 'site', path: Routes.siteMenu, label: 'Menú', permission: Permissions.menuManage, icon: Icons.restaurant_menu_rounded),
  _SiteNavItem(group: 'site', path: Routes.siteSupplies, label: 'Insumos', permission: Permissions.inventoryManage, icon: Icons.inventory_2_outlined),
  _SiteNavItem(group: 'reports', path: Routes.siteMetrics, label: 'Métricas', permission: Permissions.reportsView, icon: Icons.bar_chart_rounded),
  _SiteNavItem(group: 'reports', path: Routes.siteClosing, label: 'Cierre del día', permission: Permissions.reportsView, icon: Icons.verified_outlined),
];

const Map<String, String> _groupLabel = {
  'service': 'Servicio en curso',
  'site': 'Sede',
  'reports': 'Reportes',
};

/// Menú lateral del portal (equivale a PortalSidebar.vue).
class PortalDrawer extends StatelessWidget {
  const PortalDrawer({super.key, required this.state});

  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final activity = context.watch<SiteActivityStore>();
    final c = context.colors;
    final path = state.uri.path;
    final slug = currentSiteSlug(state);
    final site = slug == null ? null : SiteDirectory.lookup(slug);
    final visibleSiteItems = _siteItems.where((item) => session.can(item.permission)).toList();
    final showSedes = session.hasSiteAccess && (session.user?.restaurantIds.length ?? 0) != 1;
    final showFinance = session.can(Permissions.reportsView);

    int badgeCount(String? key) => switch (key) {
          'incoming' => activity.counts.incoming,
          'kitchen' => activity.counts.kitchen,
          'ready' => activity.counts.ready,
          'accountRequested' => activity.counts.accountRequested,
          _ => 0,
        };

    Widget heading(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(label.toUpperCase(), style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
        );

    Widget item({required String label, required IconData icon, required bool active, required String to, int badge = 0}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Material(
          color: active ? c.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).pop();
              context.go(to);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: active ? c.onPrimaryContainer : c.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label, style: AppFonts.label(fontSize: 14, color: active ? c.onPrimaryContainer : c.onSurfaceVariant)),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(999)),
                        child: Text('$badge', style: AppFonts.label(fontSize: 12, fontWeight: FontWeight.w700, color: c.onError)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (showSedes || showFinance) ...[
              heading('Cadena'),
              if (showSedes) item(label: 'Sedes', icon: Icons.apartment_rounded, active: path == Routes.dashboard, to: Routes.dashboard),
              if (showFinance)
                item(label: 'Finanzas', icon: Icons.payments_outlined, active: path.startsWith(Routes.finance), to: Routes.finance),
            ],
            if (slug != null && visibleSiteItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text(site?.name ?? 'Sede', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
              ),
              for (final group in ['service', 'site', 'reports'])
                if (visibleSiteItems.any((entry) => entry.group == group)) ...[
                  heading(_groupLabel[group]!),
                  for (final entry in visibleSiteItems.where((entry) => entry.group == group))
                    item(
                      label: entry.label,
                      icon: entry.icon,
                      to: entry.path(slug),
                      active: path == entry.path(slug) || (entry.extraMatch?.hasMatch(path) ?? false),
                      badge: badgeCount(entry.badge),
                    ),
                ],
            ],
            if (session.hasAdminAccess) ...[
              heading('Organización'),
              item(label: 'Administración', icon: Icons.tune_rounded, active: path.startsWith(Routes.adminHome), to: Routes.adminHome),
            ],
            if (session.user != null) ...[
              const Divider(height: 32),
              ListTile(
                leading: InitialsAvatar(name: session.user!.name),
                title: const Text('Mi perfil', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([session.user!.name, if (session.user!.roleName != null) session.user!.roleName!].join(' · ')),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(Routes.staffProfile);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
