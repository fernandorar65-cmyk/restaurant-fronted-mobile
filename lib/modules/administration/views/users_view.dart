import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/empty_state.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/admin_form.dart';
import '../widgets/user_access_dialog.dart';

/// Cuentas de acceso del personal (equivale a UsersView.vue).
class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  List<SystemUser> _users = [];
  List<Employee> _employees = [];
  List<Role> _roles = [];
  List<RestaurantSite> _restaurants = [];
  String? _loadError;
  String? _actionError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  String _employeeName(SystemUser user) =>
      _employees.where((employee) => employee.id == user.employeeId).firstOrNull?.name ?? 'Sin empleado';

  String _roleName(SystemUser user) => _roles.where((role) => role.id == user.roleId).firstOrNull?.name ?? 'Sin rol';

  String _sitesLabel(SystemUser user) {
    if (user.restaurantIds.isEmpty) {
      return 'Todas las sedes';
    }

    return user.restaurantIds.map((id) => _restaurants.where((site) => site.id == id).firstOrNull?.name ?? id).join(', ');
  }

  ({String label, StatusTone tone}) _statusOf(SystemUser user) {
    if (user.isBlocked) {
      return (label: 'Bloqueado', tone: 'danger');
    }

    if (!user.isActive) {
      return (label: 'Inactivo', tone: 'muted');
    }

    return (label: 'Activo', tone: 'success');
  }

  bool _isSelf(SystemUser user) => user.id == context.read<SessionStore>().user?.id;

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([fetchUsers(), fetchEmployees(), fetchRoles(), fetchRestaurants()]);
      _users = results[0] as List<SystemUser>;
      _employees = results[1] as List<Employee>;
      _roles = results[2] as List<Role>;
      _restaurants = results[3] as List<RestaurantSite>;
    } catch (error) {
      _loadError = errorText(error, 'No se pudieron cargar las cuentas.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _replaceUser(SystemUser updated) {
    setState(() => _users = _users.map((item) => item.id == updated.id ? updated : item).toList());
  }

  Future<void> _toggleActive(SystemUser user) async {
    setState(() => _actionError = null);

    try {
      final updated = await updateUserActive(user.id, !user.isActive);
      if (mounted) _replaceUser(updated);
    } catch (_) {
      if (mounted) setState(() => _actionError = 'No se pudo actualizar la cuenta.');
    }
  }

  Future<void> _toggleBlocked(SystemUser user) async {
    final toast = context.read<ToastStore>();
    setState(() => _actionError = null);

    try {
      final updated = await updateUserBlocked(user.id, !user.isBlocked);
      if (mounted) _replaceUser(updated);
      toast.show(
        user.isBlocked ? '${user.name} desbloqueado' : '${user.name} bloqueado',
        message: user.isBlocked ? null : 'Ya no puede iniciar sesión y se cierra su sesión abierta.',
      );
    } catch (_) {
      if (mounted) setState(() => _actionError = 'No se pudo actualizar la cuenta.');
    }
  }

  Future<String?> _saveAccess(SystemUser user, SystemUserDraft draft) async {
    final session = context.read<SessionStore>();
    final toast = context.read<ToastStore>();
    final isSelf = _isSelf(user);
    setState(() => _actionError = null);

    try {
      await updateUserAccess(user, draft);
    } catch (_) {
      return 'No se pudo guardar el acceso.';
    }

    // La hoja se cierra en cuanto el acceso quedó guardado; la recarga sigue detrás.
    () async {
      await _loadUsers();

      if (isSelf) {
        await session.refreshUser().catchError((_) => true);
      }

      toast.show('Acceso actualizado', tone: 'success');
    }();

    return null;
  }

  void _openAccess(SystemUser user) {
    UserAccessDialog.show(
      context,
      user: user,
      roles: _roles,
      restaurants: _restaurants,
      employees: _employees,
      onSave: (draft) => _saveAccess(user, draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Se observa la sesión para marcar "(tú)" correctamente si cambia el usuario.
    final selfId = context.watch<SessionStore>().user?.id;

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminPageHeader(
            section: 'Usuarios',
            title: 'Usuarios',
            description:
                'Cuentas de acceso del personal: rol, sedes a las que entra y empleado vinculado. Un usuario bloqueado no puede iniciar sesión.',
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else ...[
            if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
            if (_users.isEmpty) const EmptyState(title: 'No hay cuentas registradas.'),
            for (final user in _users) ...[
              _UserCard(
                user: user,
                isSelf: user.id == selfId,
                roleName: _roleName(user),
                hasRole: user.roleId != null,
                sitesLabel: _sitesLabel(user),
                employeeName: _employeeName(user),
                status: _statusOf(user),
                errorColor: c.error,
                onAccess: () => _openAccess(user),
                onToggleActive: () => _toggleActive(user),
                onToggleBlocked: () => _toggleBlocked(user),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.roleName,
    required this.hasRole,
    required this.sitesLabel,
    required this.employeeName,
    required this.status,
    required this.errorColor,
    required this.onAccess,
    required this.onToggleActive,
    required this.onToggleBlocked,
  });

  final SystemUser user;
  final bool isSelf;
  final String roleName;
  final bool hasRole;
  final String sitesLabel;
  final String employeeName;
  final ({String label, StatusTone tone}) status;
  final Color errorColor;
  final VoidCallback onAccess;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleBlocked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget detail(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: c.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color ?? c.onSurfaceVariant))),
            ],
          ),
        );

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      onTap: onAccess,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: user.name,
                    style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                    children: [
                      if (isSelf)
                        TextSpan(text: ' (tú)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(user.email, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                const SizedBox(height: 6),
                detail(Icons.shield_outlined, roleName, color: hasRole ? c.onSurface : errorColor),
                detail(Icons.storefront_outlined, sitesLabel),
                detail(Icons.badge_outlined, employeeName),
                const SizedBox(height: 8),
                StatusBadge(tone: status.tone, label: status.label),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'access':
                  onAccess();
                case 'active':
                  onToggleActive();
                case 'blocked':
                  onToggleBlocked();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'access', child: Text('Acceso')),
              if (!isSelf) ...[
                PopupMenuItem(value: 'active', child: Text(user.isActive ? 'Desactivar' : 'Activar')),
                PopupMenuItem(
                  value: 'blocked',
                  child: Text(user.isBlocked ? 'Desbloquear' : 'Bloquear', style: TextStyle(color: user.isBlocked ? c.primaryInk : c.error)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
