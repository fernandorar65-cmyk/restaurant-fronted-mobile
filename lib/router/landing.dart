import '../core/config/features.dart';
import '../modules/auth/permissions.dart';
import '../modules/auth/types.dart';
import 'routes.dart';
import 'site_directory.dart';

/// Vista principal de cada permiso dentro de una sede, en orden de prioridad.
final List<({Permission permission, String Function(String slug) path})> _siteLanding = [
  (permission: Permissions.sitesManage, path: Routes.siteDashboard),
  if (Features.kitchenQueue) (permission: Permissions.kitchenManage, path: Routes.siteKitchen),
  (permission: Permissions.ordersManage, path: Routes.siteOrders),
  (permission: Permissions.paymentsManage, path: Routes.siteAccounts),
  (permission: Permissions.menuManage, path: Routes.siteMenu),
  (permission: Permissions.reportsView, path: Routes.siteMetrics),
];

/// Primera vista de sede a la que el usuario tiene acceso.
String? siteLandingRoute(AuthUser? user, String restaurantId) {
  for (final item in _siteLanding) {
    if (user?.permissions.contains(item.permission) ?? false) {
      return item.path(SiteDirectory.slugFor(restaurantId));
    }
  }

  return null;
}

/// A dónde va cada usuario al iniciar sesión, según su rol y sus sedes.
String landingRouteFor(AuthUser? user) {
  if (user == null || user.permissions.isEmpty) {
    return Routes.noAccess;
  }

  if (user.restaurantIds.length == 1) {
    final siteRoute = siteLandingRoute(user, user.restaurantIds.first);

    if (siteRoute != null) {
      return siteRoute;
    }
  }

  if (_siteLanding.any((item) => user.permissions.contains(item.permission))) {
    return Routes.dashboard;
  }

  return Routes.adminHome;
}
