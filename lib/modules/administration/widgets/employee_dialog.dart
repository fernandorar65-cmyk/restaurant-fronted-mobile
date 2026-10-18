import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../restaurants/types.dart';
import '../admin_labels.dart';
import '../types.dart';
import 'admin_form.dart';

/// Guarda el borrador; devuelve null si salió bien (la hoja se cierra) o el mensaje de error.
typedef DraftSaver<T> = Future<String?> Function(T draft);

/// Alta / edición de un empleado (equivale a EmployeeDialog.vue).
class EmployeeDialog extends StatefulWidget {
  const EmployeeDialog({
    super.key,
    required this.employee,
    required this.roles,
    required this.restaurants,
    required this.users,
    required this.linkedUserIds,
    required this.onSave,
  });

  /// null = alta de un empleado nuevo.
  final Employee? employee;
  final List<Role> roles;
  final List<RestaurantSite> restaurants;
  final List<SystemUser> users;
  final List<String> linkedUserIds;
  final DraftSaver<EmployeeDraft> onSave;

  static Future<void> show(
    BuildContext context, {
    Employee? employee,
    required List<Role> roles,
    required List<RestaurantSite> restaurants,
    required List<SystemUser> users,
    required List<String> linkedUserIds,
    required DraftSaver<EmployeeDraft> onSave,
  }) {
    return showBaseDialog<void>(
      context,
      eyebrow: 'Empleado',
      title: employee?.name ?? 'Nuevo empleado',
      builder: (_) => EmployeeDialog(
        employee: employee,
        roles: roles,
        restaurants: restaurants,
        users: users,
        linkedUserIds: linkedUserIds,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<EmployeeDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.employee?.name ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.employee?.email ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.employee?.phone ?? '');
  late String _roleId = widget.employee?.roleId ?? widget.roles.firstOrNull?.id ?? '';
  late String _restaurantId = widget.employee?.restaurantId ?? widget.restaurants.firstOrNull?.id ?? '';
  late EmployeeArea _area = widget.employee?.area ?? 'floor';
  late EmployeeStatus _status = widget.employee?.status ?? 'active';
  late String _userId = widget.employee?.userId ?? '';
  String? _formError;
  bool _saving = false;

  late final List<SystemUser> _availableUsers = widget.users
      .where((user) => user.id == widget.employee?.userId || !widget.linkedUserIds.contains(user.id))
      .toList();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 2) {
      setState(() => _formError = 'Indica el nombre del empleado.');
      return;
    }

    if (_roleId.isEmpty || _restaurantId.isEmpty) {
      setState(() => _formError = 'Elige puesto y sede.');
      return;
    }

    setState(() {
      _formError = null;
      _saving = true;
    });

    final navigator = Navigator.of(context);
    final error = await widget.onSave(
      EmployeeDraft(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        roleId: _roleId,
        restaurantId: _restaurantId,
        area: _area,
        status: _status,
        userId: _userId.isEmpty ? null : _userId,
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
    // Valores que ya no existen en la lista (p. ej. un rol eliminado) no deben romper el selector.
    final roleValue = widget.roles.any((role) => role.id == _roleId) ? _roleId : null;
    final restaurantValue = widget.restaurants.any((site) => site.id == _restaurantId) ? _restaurantId : null;
    final userValue = _availableUsers.any((user) => user.id == _userId) ? _userId : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        fieldGap,
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
        fieldGap,
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        fieldGap,
        DropdownButtonFormField<String>(
          initialValue: roleValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Puesto'),
          items: [for (final role in widget.roles) DropdownMenuItem(value: role.id, child: Text(role.name))],
          onChanged: (value) => setState(() => _roleId = value ?? ''),
        ),
        fieldGap,
        DropdownButtonFormField<String>(
          initialValue: restaurantValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sede'),
          items: [
            for (final site in widget.restaurants)
              DropdownMenuItem(value: site.id, child: Text(site.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) => setState(() => _restaurantId = value ?? ''),
        ),
        fieldGap,
        FieldPair(
          first: DropdownButtonFormField<String>(
            initialValue: _area,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Área'),
            items: [
              for (final entry in employeeAreaLabel.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _area = value ?? _area),
          ),
          second: DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              for (final entry in employeeStatusLabel.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),
        fieldGap,
        DropdownButtonFormField<String>(
          initialValue: userValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cuenta del sistema vinculada'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Sin cuenta del sistema')),
            for (final user in _availableUsers)
              DropdownMenuItem(value: user.id, child: Text(user.email, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) => setState(() => _userId = value ?? ''),
        ),
        const SizedBox(height: 6),
        Text(
          'Un empleado puede existir sin cuenta de acceso; esto solo lo vincula a un login.',
          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
        ),
        if (_formError != null) ...[fieldGap, InlineAlert(_formError!)],
        const SizedBox(height: 20),
        DialogActions(onSubmit: _submit, loading: _saving),
      ],
    );
  }
}
