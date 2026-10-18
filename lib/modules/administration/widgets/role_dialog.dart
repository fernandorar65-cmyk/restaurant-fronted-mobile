import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../auth/permissions.dart';
import '../types.dart';
import 'admin_form.dart';
import 'employee_dialog.dart' show DraftSaver;

/// Alta / edición de un rol con sus permisos (equivale a RoleDialog.vue).
class RoleDialog extends StatefulWidget {
  const RoleDialog({super.key, required this.role, required this.onSave});

  /// null = nuevo rol.
  final Role? role;
  final DraftSaver<RoleDraft> onSave;

  static Future<void> show(BuildContext context, {Role? role, required DraftSaver<RoleDraft> onSave}) {
    return showBaseDialog<void>(
      context,
      title: role != null ? 'Editar rol: ${role.name}' : 'Nuevo rol',
      builder: (_) => RoleDialog(role: role, onSave: onSave),
    );
  }

  @override
  State<RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<RoleDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.role?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.role?.description ?? '');
  late List<Permission> _permissions = [...?widget.role?.permissions];
  String? _formError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _togglePermission(Permission permission) {
    setState(() {
      _permissions = _permissions.contains(permission)
          ? _permissions.where((item) => item != permission).toList()
          : [..._permissions, permission];
    });
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _formError = 'El rol necesita un nombre.');
      return;
    }

    setState(() {
      _formError = null;
      _saving = true;
    });

    final navigator = Navigator.of(context);
    final error = await widget.onSave(
      RoleDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        permissions: permissionsList.where(_permissions.contains).toList(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
        fieldGap,
        TextField(
          controller: _description,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Descripción', alignLabelWithHint: true),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Permisos'),
        Container(
          decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final permission in permissionsList)
                CheckboxListTile(
                  value: _permissions.contains(permission),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(permissionLabel[permission] ?? permission, style: const TextStyle(fontSize: 14)),
                  onChanged: (_) => _togglePermission(permission),
                ),
            ],
          ),
        ),
        if (_formError != null) ...[fieldGap, InlineAlert(_formError!)],
        const SizedBox(height: 20),
        DialogActions(onSubmit: _submit, loading: _saving),
      ],
    );
  }
}
