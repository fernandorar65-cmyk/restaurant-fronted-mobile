import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../auth/permissions.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/admin_form.dart';

typedef _Section = ({String route, String title, String description, Permission permission, IconData icon});

const List<_Section> _allSections = [
  (
    route: Routes.adminRestaurants,
    title: 'Restaurantes',
    description: 'Alta de sedes, datos generales, moneda, zona horaria y estado operativo.',
    permission: Permissions.orgManage,
    icon: Icons.storefront_outlined,
  ),
  (
    route: Routes.adminEmployees,
    title: 'Empleados',
    description: 'Directorio de personal: alta, baja, puesto, sede y contacto.',
    permission: Permissions.staffManage,
    icon: Icons.badge_outlined,
  ),
  (
    route: Routes.adminUsers,
    title: 'Usuarios',
    description: 'Cuentas de acceso: rol, sedes, activar, bloquear y vincular a un empleado.',
    permission: Permissions.usersManage,
    icon: Icons.manage_accounts_outlined,
  ),
  (
    route: Routes.adminRoles,
    title: 'Roles y permisos',
    description: 'Crea y edita roles; cada permiso habilita secciones del portal.',
    permission: Permissions.usersManage,
    icon: Icons.shield_outlined,
  ),
  (
    route: Routes.adminInventory,
    title: 'Inventario',
    description: 'Insumos por sede, cantidades mínimas y alertas de stock.',
    permission: Permissions.inventoryManage,
    icon: Icons.inventory_2_outlined,
  ),
  (
    route: Routes.adminSettings,
    title: 'Configuración',
    description: 'Datos generales de la organización.',
    permission: Permissions.orgManage,
    icon: Icons.settings_outlined,
  ),
];

/// Inicio de Administración: resumen de la cadena y accesos a cada sección (equivale a AdminHomeView.vue).
class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  Organization? _organization;
  List<RestaurantSite> _restaurants = [];
  List<Employee> _employees = [];
  List<Role> _roles = [];
  List<InventoryItem> _inventory = [];
  String? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([
        fetchOrganizations(),
        fetchRestaurants(),
        fetchEmployees(),
        fetchRoles(),
        fetchInventoryItems(),
      ]);
      _organization = (results[0] as List<Organization>).firstOrNull;
      _restaurants = results[1] as List<RestaurantSite>;
      _employees = results[2] as List<Employee>;
      _roles = results[3] as List<Role>;
      _inventory = results[4] as List<InventoryItem>;
    } catch (error) {
      _loadError = errorText(error, 'No se pudo cargar el panel de administración.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final inventoryAlerts = _inventory
        .where((item) => item.isActive && item.status != 'ok' && session.canAccessRestaurant(item.restaurantId))
        .length;
    final sections = _allSections.where((section) => session.can(section.permission)).toList();

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text((_organization?.name ?? 'Organización').toUpperCase(), style: AppFonts.eyebrow(color: c.primary)),
          const SizedBox(height: 4),
          Text('Administración', style: AppFonts.headline(fontSize: 26, color: c.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Restaurantes, empleados, roles, inventario y configuración de toda la cadena.',
            style: TextStyle(fontSize: 15, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else ...[
            TwoColumnGrid(
              children: [
                StatTile(label: 'Sedes', value: '${_restaurants.length}'),
                StatTile(label: 'Empleados', value: '${_employees.length}'),
                StatTile(label: 'Roles', value: '${_roles.length}'),
                StatTile(
                  label: 'Alertas de stock',
                  value: '$inventoryAlerts',
                  valueColor: inventoryAlerts > 0 ? c.error : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              AdminCard(
                onTap: () => context.go(section.route),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(12)),
                      child: Icon(section.icon, color: c.onPrimaryFixed),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(section.title, style: AppFonts.headline(fontSize: 17, color: c.onSurface)),
                          const SizedBox(height: 2),
                          Text(section.description, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.primary),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}
