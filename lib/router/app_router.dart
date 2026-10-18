import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/features.dart';
import '../layouts/customer_shell.dart';
import '../layouts/portal_shell.dart';
import '../modules/administration/views/admin_home_view.dart';
import '../modules/administration/views/dashboard_view.dart';
import '../modules/administration/views/employees_view.dart';
import '../modules/administration/views/inventory_view.dart';
import '../modules/administration/views/organization_settings_view.dart';
import '../modules/administration/views/restaurants_admin_view.dart';
import '../modules/administration/views/roles_view.dart';
import '../modules/administration/views/users_view.dart';
import '../modules/auth/permissions.dart';
import '../modules/auth/views/access_view.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';
import '../modules/auth/views/staff_profile_view.dart';
import '../modules/diners/views/diner_auth_view.dart';
import '../modules/diners/views/diner_profile_view.dart';
import '../modules/diners/views/diner_visits_view.dart';
import '../modules/finance/views/finance_site_view.dart';
import '../modules/finance/views/finance_view.dart';
import '../modules/inventory/views/site_supplies_view.dart';
import '../modules/landing/views/restaurant_landing_view.dart';
import '../modules/menus/views/menu_view.dart';
import '../modules/menus/views/site_menu_view.dart';
import '../modules/orders/views/cart_view.dart';
import '../modules/orders/views/kitchen_queue_view.dart';
import '../modules/orders/views/order_status_view.dart';
import '../modules/orders/views/site_accounts_view.dart';
import '../modules/orders/views/site_orders_view.dart';
import '../modules/payments/views/checkout_result_view.dart';
import '../modules/payments/views/checkout_view.dart';
import '../modules/payments/views/customer_account_view.dart';
import '../modules/payments/views/fulfillment_view.dart';
import '../modules/payments/views/payment_method_view.dart';
import '../modules/reports/views/daily_closing_view.dart';
import '../modules/reports/views/site_metrics_view.dart';
import '../modules/restaurants/views/restaurant_select_view.dart';
import '../modules/restaurants/views/site_dashboard_view.dart';
import '../modules/restaurants/views/table_entry_view.dart';
import '../stores/diner_store.dart';
import '../stores/session_store.dart';
import '../widgets/feedback/no_access_view.dart';
import '../widgets/feedback/not_found_view.dart';
import 'landing.dart';
import 'routes.dart';
import 'site_directory.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _customerShellKey = GlobalKey<NavigatorState>(debugLabel: 'customer');
final GlobalKey<NavigatorState> _portalShellKey = GlobalKey<NavigatorState>(debugLabel: 'portal');

/// Permiso que pide cada ruta del portal (equivale a `meta.permission` / `meta.anyPermission`).
final List<({RegExp pattern, Permission? permission, List<Permission>? anyPermission})> _portalRules = [
  (pattern: RegExp(r'^/owner/dashboard$'), permission: null, anyPermission: sitePermissions),
  (pattern: RegExp(r'^/owner/finanzas(/[^/]+)?$'), permission: Permissions.reportsView, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+$'), permission: Permissions.sitesManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+/pedidos(/[^/]+)?$'), permission: Permissions.ordersManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+/cocina$'), permission: Permissions.kitchenManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+/menu$'), permission: Permissions.menuManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+/cuentas(/[^/]+)?$'), permission: Permissions.paymentsManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+/insumos$'), permission: Permissions.inventoryManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/sede/[^/]+/(metricas|cierre)$'), permission: Permissions.reportsView, anyPermission: null),
  (pattern: RegExp(r'^/owner/admin$'), permission: null, anyPermission: adminPermissions),
  (pattern: RegExp(r'^/owner/admin/empleados$'), permission: Permissions.staffManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/admin/(usuarios|roles)$'), permission: Permissions.usersManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/admin/inventario$'), permission: Permissions.inventoryManage, anyPermission: null),
  (pattern: RegExp(r'^/owner/admin/(restaurantes|configuracion)$'), permission: Permissions.orgManage, anyPermission: null),
];

final RegExp _sitePath = RegExp(r'^/owner/sede/([^/]+)(/.*)?$');
final RegExp _financeSitePath = RegExp(r'^/owner/finanzas/([^/]+)$');

String? _query(GoRouterState state, String key) => state.uri.queryParameters[key];

GoRouter createRouter({required SessionStore session, required DinerStore diner}) {
  Future<String?> guard(BuildContext context, GoRouterState state) async {
    final path = state.uri.path;
    final requiresAuth = path == '/owner' || (path.startsWith('/owner/') && !path.startsWith('/owner/auth'));
    final guestOnly = path.startsWith('/owner/auth');

    if (requiresAuth && !session.isAuthenticated) {
      return Uri(path: Routes.login, queryParameters: {'redirect': state.uri.toString()}).toString();
    }

    if (guestOnly && session.isAuthenticated) {
      return landingRouteFor(session.user);
    }

    if (!requiresAuth || path == Routes.noAccess) {
      return null;
    }

    try {
      await SiteDirectory.ensure();
    } catch (_) {
      // Sin conexión: la vista mostrará el error al cargar.
    }

    String? restaurantId = _financeSitePath.firstMatch(path)?.group(1);

    // Rutas de sede (/owner/sede/:siteSlug): el slug se traduce al id de la sede.
    final siteMatch = _sitePath.firstMatch(path);
    if (siteMatch != null) {
      final slug = siteMatch.group(1)!;
      final rest = siteMatch.group(2) ?? '';

      // La sección Entregas se eliminó y la Cocina puede estar apagada: llevan a Gestión de pedidos.
      if (rest == '/entregas' || (rest == '/cocina' && !Features.kitchenQueue)) {
        return Routes.siteOrders(slug);
      }

      ({String id, String slug})? site;
      try {
        site = await SiteDirectory.find(slug);
      } catch (_) {
        site = null;
      }

      if (site == null) {
        return '/no-encontrado';
      }

      // Si llegó con el id (o un slug viejo), se corrige la ruta al nombre del local.
      if (site.slug != slug) {
        return state.uri.replace(path: '/owner/sede/${site.slug}$rest').toString();
      }

      restaurantId = site.id;
    }

    if (restaurantId != null && !session.canAccessRestaurant(restaurantId)) {
      return '${Routes.noAccess}?motivo=sede';
    }

    for (final rule in _portalRules) {
      if (!rule.pattern.hasMatch(path)) continue;

      if (rule.permission != null && !session.can(rule.permission!)) {
        return '${Routes.noAccess}?motivo=permiso';
      }

      if (rule.anyPermission != null && !rule.anyPermission!.any(session.can)) {
        final landing = landingRouteFor(session.user);
        return landing == path ? Routes.noAccess : landing;
      }

      break;
    }

    return null;
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: session,
    redirect: guard,
    errorBuilder: (context, state) => const NotFoundView(),
    routes: [
      // ── COMENSAL ──────────────────────────────────────────────────────
      // Público. Entra escaneando el QR de su mesa (o elige una sede solo
      // para consultar la carta), confirma la mesa, pide, sigue su pedido y
      // consulta la cuenta. Puede usar una cuenta de comensal opcional.
      ShellRoute(
        navigatorKey: _customerShellKey,
        builder: (context, state, child) => CustomerShell(state: state, child: child),
        routes: [
          GoRoute(path: '/', name: 'home', builder: (context, state) => const RestaurantSelectView()),
          GoRoute(
            path: '/table/:tableId',
            name: 'table-entry',
            builder: (context, state) => TableEntryView(tableId: state.pathParameters['tableId']!),
          ),
          GoRoute(path: '/menu', redirect: (context, state) => diner.menuRoute),
          GoRoute(path: '/cart', name: 'cart', builder: (context, state) => const CartView()),
          GoRoute(path: '/pedido/entrega', name: 'checkout-fulfillment', builder: (context, state) => const FulfillmentView()),
          GoRoute(path: '/pago', name: 'checkout', builder: (context, state) => const CheckoutView()),
          GoRoute(path: '/pago/listo', name: 'checkout-result', builder: (context, state) => const CheckoutResultView()),
          GoRoute(
            path: '/pago/:method',
            name: 'checkout-method',
            builder: (context, state) => PaymentMethodView(method: state.pathParameters['method']!),
          ),
          GoRoute(
            path: '/orders/:attentionId',
            name: 'order-status',
            builder: (context, state) => OrderStatusView(attentionId: state.pathParameters['attentionId']!),
            routes: [
              GoRoute(
                path: 'cuenta',
                name: 'order-account',
                builder: (context, state) => CustomerAccountView(attentionId: state.pathParameters['attentionId']!),
              ),
              GoRoute(path: 'pay', redirect: (context, state) => Routes.orderAccount(state.pathParameters['attentionId']!)),
            ],
          ),
          // Elegir tipo de cuenta antes de iniciar sesión o registrarse (?modo=registro).
          GoRoute(path: '/acceso', name: 'access', builder: (context, state) => AccessView(mode: _query(state, 'modo'))),
          GoRoute(path: '/perfil', name: 'diner-profile', builder: (context, state) => const DinerProfileView()),
          GoRoute(path: '/mis-visitas', name: 'diner-visits', builder: (context, state) => const DinerVisitsView()),
          GoRoute(
            path: '/:restaurantSlug/menu',
            name: 'menu',
            builder: (context, state) => MenuView(restaurantSlug: state.pathParameters['restaurantSlug']!),
          ),
        ],
      ),
      // ── ACCESO ────────────────────────────────────────────────────────
      GoRoute(path: '/customer/auth', redirect: (context, state) => Routes.dinerAuth),
      GoRoute(
        path: '/customer/auth/login',
        name: 'diner-auth',
        builder: (context, state) => DinerAuthView(register: false, redirect: _query(state, 'redirect')),
      ),
      GoRoute(
        path: '/customer/auth/register',
        name: 'diner-register',
        builder: (context, state) => DinerAuthView(register: true, redirect: _query(state, 'redirect')),
      ),
      GoRoute(path: '/owner/auth', redirect: (context, state) => Routes.login),
      GoRoute(
        path: '/owner/auth/login',
        name: 'login',
        builder: (context, state) => LoginView(redirect: _query(state, 'redirect')),
      ),
      GoRoute(path: '/owner/auth/register', name: 'register', builder: (context, state) => const RegisterView()),
      // ── RESTAURANTE (dueño y personal) ────────────────────────────────
      // Todo el portal vive bajo /owner. Requiere login; cada ruta pide un permiso.
      GoRoute(path: '/owner', redirect: (context, state) => Routes.dashboard),
      ShellRoute(
        navigatorKey: _portalShellKey,
        builder: (context, state, child) => PortalShell(state: state, child: child),
        routes: [
          GoRoute(path: '/owner/dashboard', name: 'dashboard', builder: (context, state) => const DashboardView()),
          GoRoute(
            path: '/owner/sin-acceso',
            name: 'no-access',
            builder: (context, state) => NoAccessView(reason: _query(state, 'motivo')),
          ),
          GoRoute(path: '/owner/finanzas', name: 'finance', builder: (context, state) => const FinanceView()),
          GoRoute(
            path: '/owner/finanzas/:restaurantId',
            name: 'finance-site',
            builder: (context, state) => FinanceSiteView(restaurantId: state.pathParameters['restaurantId']!),
          ),
          GoRoute(
            path: '/owner/sede/:siteSlug',
            name: 'site-dashboard',
            builder: (context, state) => SiteDashboardView(siteSlug: state.pathParameters['siteSlug']!),
            routes: [
              GoRoute(
                path: 'pedidos',
                name: 'site-orders',
                builder: (context, state) => SiteOrdersView(siteSlug: state.pathParameters['siteSlug']!),
              ),
              GoRoute(
                path: 'pedidos/:attentionId',
                name: 'site-order-detail',
                builder: (context, state) => SiteOrdersView(
                  siteSlug: state.pathParameters['siteSlug']!,
                  attentionId: state.pathParameters['attentionId'],
                ),
              ),
              GoRoute(
                path: 'cocina',
                name: 'site-kitchen',
                builder: (context, state) => KitchenQueueView(siteSlug: state.pathParameters['siteSlug']!),
              ),
              GoRoute(
                path: 'menu',
                name: 'site-menu',
                builder: (context, state) => SiteMenuView(siteSlug: state.pathParameters['siteSlug']!),
              ),
              GoRoute(
                path: 'cuentas',
                name: 'site-accounts',
                builder: (context, state) => SiteAccountsView(
                  siteSlug: state.pathParameters['siteSlug']!,
                  view: _query(state, 'vista'),
                ),
              ),
              GoRoute(
                path: 'cuentas/:attentionId',
                name: 'site-account-detail',
                builder: (context, state) => SiteAccountsView(
                  siteSlug: state.pathParameters['siteSlug']!,
                  attentionId: state.pathParameters['attentionId'],
                  view: _query(state, 'vista'),
                ),
              ),
              GoRoute(
                path: 'insumos',
                name: 'site-supplies',
                builder: (context, state) => SiteSuppliesView(
                  siteSlug: state.pathParameters['siteSlug']!,
                  view: _query(state, 'vista'),
                ),
              ),
              GoRoute(
                path: 'metricas',
                name: 'site-metrics',
                builder: (context, state) => SiteMetricsView(siteSlug: state.pathParameters['siteSlug']!),
              ),
              GoRoute(
                path: 'cierre',
                name: 'site-closing',
                builder: (context, state) => DailyClosingView(siteSlug: state.pathParameters['siteSlug']!),
              ),
            ],
          ),
          GoRoute(path: '/owner/cuenta', name: 'staff-profile', builder: (context, state) => const StaffProfileView()),
          GoRoute(
            path: '/owner/admin',
            name: 'admin-home',
            builder: (context, state) => const AdminHomeView(),
            routes: [
              GoRoute(path: 'empleados', name: 'admin-employees', builder: (context, state) => const EmployeesView()),
              GoRoute(path: 'usuarios', name: 'admin-users', builder: (context, state) => const UsersView()),
              GoRoute(path: 'roles', name: 'admin-roles', builder: (context, state) => const RolesView()),
              GoRoute(path: 'inventario', name: 'admin-inventory', builder: (context, state) => const InventoryView()),
              GoRoute(path: 'restaurantes', name: 'admin-restaurants', builder: (context, state) => const RestaurantsAdminView()),
              GoRoute(path: 'configuracion', name: 'admin-settings', builder: (context, state) => const OrganizationSettingsView()),
            ],
          ),
        ],
      ),
      // Landing comercial para dueños de restaurante. Pública y sin layout propio.
      GoRoute(path: '/para-restaurantes', name: 'restaurant-landing', builder: (context, state) => const RestaurantLandingView()),
      GoRoute(path: '/no-encontrado', name: 'not-found', builder: (context, state) => const NotFoundView()),
    ],
  );
}
