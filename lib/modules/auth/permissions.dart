/// Permisos del portal. Se guardan como texto, igual que en `db.json`.
typedef Permission = String;

class Permissions {
  Permissions._();

  static const orgManage = 'org.manage';
  static const usersManage = 'users.manage';
  static const staffManage = 'staff.manage';
  static const sitesManage = 'sites.manage';
  static const ordersManage = 'orders.manage';
  static const kitchenManage = 'kitchen.manage';
  static const menuManage = 'menu.manage';
  static const paymentsManage = 'payments.manage';
  static const inventoryManage = 'inventory.manage';
  static const reportsView = 'reports.view';
}

const List<Permission> permissionsList = [
  Permissions.orgManage,
  Permissions.usersManage,
  Permissions.staffManage,
  Permissions.sitesManage,
  Permissions.ordersManage,
  Permissions.kitchenManage,
  Permissions.menuManage,
  Permissions.paymentsManage,
  Permissions.inventoryManage,
  Permissions.reportsView,
];

const Map<Permission, String> permissionLabel = {
  Permissions.orgManage: 'Organización y sedes',
  Permissions.usersManage: 'Usuarios y roles',
  Permissions.staffManage: 'Empleados',
  Permissions.sitesManage: 'Sala, mesas y QR',
  Permissions.ordersManage: 'Gestión de pedidos y pedido manual',
  Permissions.kitchenManage: 'Cola de cocina',
  Permissions.menuManage: 'Menú y productos',
  Permissions.paymentsManage: 'Cuentas y cobros',
  Permissions.inventoryManage: 'Inventario',
  Permissions.reportsView: 'Métricas y cierre del día',
};

bool isPermission(Object? value) => value is String && permissionsList.contains(value);

const List<Permission> adminPermissions = [
  Permissions.orgManage,
  Permissions.usersManage,
  Permissions.staffManage,
  Permissions.inventoryManage,
];

/// Permisos que habilitan al menos una vista dentro de una sede.
const List<Permission> sitePermissions = [
  Permissions.sitesManage,
  Permissions.ordersManage,
  Permissions.kitchenManage,
  Permissions.menuManage,
  Permissions.paymentsManage,
  Permissions.inventoryManage,
  Permissions.reportsView,
];
