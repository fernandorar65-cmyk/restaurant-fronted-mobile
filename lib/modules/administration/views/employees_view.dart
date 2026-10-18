import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/empty_state.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../../widgets/navigation/avatar.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../admin_labels.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/admin_form.dart';
import '../widgets/employee_dialog.dart';

/// Directorio de personal de la organización (equivale a EmployeesView.vue).
class EmployeesView extends StatefulWidget {
  const EmployeesView({super.key});

  @override
  State<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<EmployeesView> {
  final TextEditingController _search = TextEditingController();

  List<Employee> _employees = [];
  List<Role> _roles = [];
  List<RestaurantSite> _restaurants = [];
  List<SystemUser> _users = [];
  String? _loadError;
  String? _actionError;
  bool _isLoading = true;

  /// 'all' | EmployeeArea
  String _areaFilter = 'all';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadEmployees();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _linkedUserIds => _employees.map((employee) => employee.userId).whereType<String>().toList();

  String _userEmailFor(Employee employee) =>
      _users.where((user) => user.id == employee.userId).firstOrNull?.email ?? 'Sin cuenta del sistema';

  List<Employee> get _filteredEmployees {
    final query = _search.text.trim().toLowerCase();

    return _employees.where((employee) {
      if (_areaFilter != 'all' && employee.area != _areaFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return employee.name.toLowerCase().contains(query) ||
          employee.email.toLowerCase().contains(query) ||
          employee.restaurantName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([fetchEmployees(), fetchRoles(), fetchRestaurants(), fetchUsers()]);
      _employees = results[0] as List<Employee>;
      _roles = results[1] as List<Role>;
      _restaurants = results[2] as List<RestaurantSite>;
      _users = results[3] as List<SystemUser>;
    } catch (error) {
      _loadError = errorText(error, 'No se pudo cargar el directorio de empleados.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _saveEmployee(Employee? original, EmployeeDraft draft) async {
    final role = _roles.where((item) => item.id == draft.roleId).firstOrNull;
    final restaurant = _restaurants.where((item) => item.id == draft.restaurantId).firstOrNull;
    setState(() => _actionError = null);

    try {
      final saved = original != null
          ? await updateEmployee(original.id, draft, roleName: role?.name ?? '', restaurantName: restaurant?.name ?? '')
          : await createEmployee(draft, roleName: role?.name ?? '', restaurantName: restaurant?.name ?? '');
      await syncEmployeeUserLink(saved.id, original?.userId, draft.userId);

      if (mounted) {
        setState(() {
          _employees = original != null
              ? _employees.map((employee) => employee.id == saved.id ? saved : employee).toList()
              : [..._employees, saved];
        });
      }

      return null;
    } catch (_) {
      return 'No se pudo guardar el empleado.';
    }
  }

  void _openDialog(Employee? employee) {
    EmployeeDialog.show(
      context,
      employee: employee,
      roles: _roles,
      restaurants: _restaurants,
      users: _users,
      linkedUserIds: _linkedUserIds,
      onSave: (draft) => _saveEmployee(employee, draft),
    );
  }

  Future<void> _removeEmployee(Employee employee) async {
    final accepted = await confirmAction(
      context,
      title: '¿Dar de baja a ${employee.name}?',
      message: 'Se elimina del directorio. Su cuenta de acceso, si tiene, queda sin empleado vinculado.',
      confirmLabel: 'Dar de baja',
      tone: 'danger',
    );

    if (!accepted || !mounted) {
      return;
    }

    setState(() => _actionError = null);

    try {
      await deleteEmployee(employee);
      if (mounted) setState(() => _employees = _employees.where((item) => item.id != employee.id).toList());
    } catch (_) {
      if (mounted) setState(() => _actionError = 'No se pudo dar de baja al empleado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEmployees;

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminPageHeader(
            section: 'Empleados',
            title: 'Empleados',
            description:
                'Directorio de personal de toda la organización: puesto, sede, contacto, estado laboral y cuenta de acceso vinculada.',
            actions: [
              BaseButton(
                label: 'Empleado',
                icon: Icons.add_rounded,
                variant: 'primary',
                onPressed: _isLoading || _loadError != null ? null : () => _openDialog(null),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else ...[
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo o sede...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Limpiar', icon: const Icon(Icons.close_rounded), onPressed: _search.clear),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in {'all': 'Todas', ...employeeAreaLabel}.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _areaFilter == entry.key,
                        onSelected: (_) => setState(() => _areaFilter = entry.key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const EmptyState(title: 'No hay empleados que coincidan con el filtro.', icon: 'search')
            else
              for (final employee in filtered) ...[
                _EmployeeCard(
                  employee: employee,
                  accountLabel: _userEmailFor(employee),
                  onEdit: () => _openDialog(employee),
                  onRemove: () => _removeEmployee(employee),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.accountLabel, required this.onEdit, required this.onRemove});

  final Employee employee;
  final String accountLabel;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasAccount = employee.userId != null;

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: employee.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
                Text(
                  [employee.email, if (employee.phone.isNotEmpty) employee.phone].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  '${employee.roleName} · ${employeeAreaLabel[employee.area] ?? employee.area}',
                  style: AppFonts.label(fontSize: 13, color: c.onSurface),
                ),
                Text(employee.restaurantName, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                const SizedBox(height: 8),
                StatusBadge(
                  tone: employeeStatusTone[employee.status] ?? 'neutral',
                  label: employeeStatusLabel[employee.status] ?? employee.status,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.key_outlined, size: 14, color: c.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        accountLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasAccount ? c.onSurface : c.onSurfaceVariant,
                          fontStyle: hasAccount ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => value == 'edit' ? onEdit() : onRemove(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'remove', child: Text('Baja', style: TextStyle(color: c.error))),
            ],
          ),
        ],
      ),
    );
  }
}
