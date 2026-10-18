/// Rutas de la app (mismas que el front web, ver RUTAS.md). Navegar con
/// `context.go(Routes.cart)` o `context.push(Routes.orderStatus(id))`.
class Routes {
  Routes._();

  // ── Comensal ──
  static const home = '/';
  static String tableEntry(String tableId) => '/table/$tableId';
  static String menu(String restaurantSlug) => '/$restaurantSlug/menu';
  static const cart = '/cart';
  static const checkoutFulfillment = '/pedido/entrega';
  static const checkout = '/pago';
  static const checkoutResult = '/pago/listo';
  static String checkoutMethod(String method) => '/pago/$method';
  static String orderStatus(String attentionId) => '/orders/$attentionId';
  static String orderAccount(String attentionId) => '/orders/$attentionId/cuenta';
  static const access = '/acceso';
  static const dinerProfile = '/perfil';
  static const dinerVisits = '/mis-visitas';
  static const dinerAuth = '/customer/auth/login';
  static const dinerRegister = '/customer/auth/register';

  // ── Restaurante ──
  static const login = '/owner/auth/login';
  static const register = '/owner/auth/register';
  static const dashboard = '/owner/dashboard';
  static const noAccess = '/owner/sin-acceso';
  static const finance = '/owner/finanzas';
  static String financeSite(String restaurantId) => '/owner/finanzas/$restaurantId';
  static String siteDashboard(String slug) => '/owner/sede/$slug';
  static String siteOrders(String slug) => '/owner/sede/$slug/pedidos';
  static String siteOrderDetail(String slug, String attentionId) => '/owner/sede/$slug/pedidos/$attentionId';
  static String siteKitchen(String slug) => '/owner/sede/$slug/cocina';
  static String siteMenu(String slug) => '/owner/sede/$slug/menu';
  static String siteAccounts(String slug) => '/owner/sede/$slug/cuentas';
  static String siteAccountDetail(String slug, String attentionId) => '/owner/sede/$slug/cuentas/$attentionId';
  static String siteSupplies(String slug) => '/owner/sede/$slug/insumos';
  static String siteMetrics(String slug) => '/owner/sede/$slug/metricas';
  static String siteClosing(String slug) => '/owner/sede/$slug/cierre';
  static const staffProfile = '/owner/cuenta';
  static const adminHome = '/owner/admin';
  static const adminEmployees = '/owner/admin/empleados';
  static const adminUsers = '/owner/admin/usuarios';
  static const adminRoles = '/owner/admin/roles';
  static const adminInventory = '/owner/admin/inventario';
  static const adminRestaurants = '/owner/admin/restaurantes';
  static const adminSettings = '/owner/admin/configuracion';

  // ── Otras ──
  static const restaurantLanding = '/para-restaurantes';
}
