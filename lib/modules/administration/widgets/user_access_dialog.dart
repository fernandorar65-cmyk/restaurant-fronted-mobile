import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../restaurants/types.dart';
import '../types.dart';
import 'admin_form.dart';
import 'employee_dialog.dart' show DraftSaver;

/// Rol, sedes y empleado vinculado de una cuenta (equivale a UserAccessDialog.vue).
class UserAccessDialog extends StatefulWidget {
  const UserAccessDialog({
    super.key,
    required this.user,
    required this.roles,
    required this.restaurants,
    required this.employees,
    required this.onSave,
  });

  final SystemUser user;
  final List<Role> roles;
  final List<RestaurantSite> restaurants;
  final List<Employee> employees;
  final DraftSaver<SystemUserDraft> onSave;

  static Future<void> show(
    BuildContext context, {
    required SystemUser user,
    required List<Role> roles,
    required List<RestaurantSite> restaurants,
    required List<Employee> employees,
    required DraftSaver<SystemUserDraft> onSave,
  }) {
    return showBaseDialog<void>(
      context,
      title: 'Acceso de ${user.name}',
      subtitle: user.email,
      builder: (_) => UserAccessDialog(
        key: ValueKey(user.id),
        user: user,
        roles: roles,
        restaurants: restaurants,
        employees: employees,
        onSave: onSave,
      ),
    );
  }

  @override
  State<UserAccessDialog> createState() => _UserAccessDialogState();
}

/// Valor del selector para "sin rol" / "sin empleado" (null no distingue bien en el menú).
const String _none = '';

class _UserAccessDialogState extends State<UserAccessDialog> {
  late String _roleId = widget.user.roleId ?? _none;
  late bool _allSites = widget.user.restaurantIds.isEmpty;
  late List<String> _restaurantIds = [...widget.user.restaurantIds];
  late String _employeeId = widget.user.employeeId ?? _none;
  String? _formError;
  bool _saving = false;

  Role? get _selectedRole => widget.roles.where((role) => role.id == _roleId).firstOrNull;

  void _toggleSite(String id) {
    setState(() {
      _restaurantIds = _restaurantIds.contains(id) ? _restaurantIds.where((item) => item != id).toList() : [..._restaurantIds, id];
    });
  }

  Future<void> _submit() async {
    if (!_allSites && _restaurantIds.isEmpty) {
      setState(() => _formError = 'Elige al menos una sede o marca "Todas las sedes".');
      return;
    }

    setState(() {
      _formError = null;
      _saving = true;
    });

    final navigator = Navigator.of(context);
    final error = await widget.onSave(
      SystemUserDraft(
        roleId: _roleId == _none ? null : _roleId,
        restaurantIds: _allSites ? const [] : _restaurantIds,
        employeeId: _employeeId == _none ? null : _employeeId,
      ),
    );

    if (!mounted) return;

    if (error == null) {
      navigator.pop();
    } else {
      setState(() {
        _saving = false;
        _formError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final roleValue = _roleId == _none || widget.roles.any((role) => role.id == _roleId) ? _roleId : _none;
    final employeeValue = _employeeId == _none || widget.employees.any((employee) => employee.id == _employeeId) ? _employeeId : _none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: roleValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rol'),
          items: [
            const DropdownMenuItem(value: _none, child: Text('Sin rol (no puede entrar a ninguna sección)', overflow: TextOverflow.ellipsis)),
            for (final role in widget.roles) DropdownMenuItem(value: role.id, child: Text(role.name)),
          ],
          onChanged: (value) => setState(() => _roleId = value ?? _none),
        ),
        if (_selectedRole != null) ...[
          const SizedBox(height: 6),
          Text(_selectedRole!.description, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ],
        const SizedBox(height: 20),
        const FieldLabel('Sedes'),
        CheckboxListTile(
          value: _allSites,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Todas las sedes de la organización', style: TextStyle(fontSize: 14)),
          onChanged: (value) => setState(() => _allSites = value ?? false),
        ),
        if (!_allSites)
          Container(
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final site in widget.restaurants)
                  CheckboxListTile(
                    value: _restaurantIds.contains(site.id),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(site.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(site.city, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    onChanged: (_) => _toggleSite(site.id),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: employeeValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Empleado vinculado'),
          items: [
            const DropdownMenuItem(value: _none, child: Text('Sin empleado')),
            for (final employee in widget.employees)
              DropdownMenuItem(
                value: employee.id,
                child: Text(
                  '${employee.name} · ${employee.restaurantName}'
                  '${employee.userId != null && employee.userId!.isNotEmpty && employee.userId != widget.user.id ? ' (ya vinculado)' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _employeeId = value ?? _none),
        ),
        if (_formError != null) ...[fieldGap, InlineAlert(_formError!)],
        const SizedBox(height: 20),
        DialogActions(onSubmit: _submit, loading: _saving),
      ],
    );
  }
}
