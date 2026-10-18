import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../auth/permissions.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/admin_form.dart';
import '../widgets/role_dialog.dart';

/// Rol del dueño: no se edita ni se elimina para no dejar la organización sin administrador.
const String _ownerRoleId = 'role-0';

/// Roles y permisos del portal (equivale a RolesView.vue).
class RolesView extends StatefulWidget {
  const RolesView({super.key});

  @override
  State<RolesView> createState() => _RolesViewState();
}

class _RolesViewState extends State<RolesView> {
  List<Role> _roles = [];
  List<SystemUser> _users = [];
  String? _loadError;
  String? _actionError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  int _usersWithRole(Role role) => _users.where((user) => user.roleId == role.id).length;

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([fetchRoles(), fetchUsers()]);
      _roles = results[0] as List<Role>;
      _users = results[1] as List<SystemUser>;
    } catch (error) {
      _loadError = errorText(error, 'No se pudieron cargar los roles.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _saveRole(Role? original, RoleDraft draft) async {
    final session = context.read<SessionStore>();
    final toast = context.read<ToastStore>();
    setState(() => _actionError = null);

    try {
      if (original != null) {
        final updated = await updateRole(original.id, draft);
        if (mounted) setState(() => _roles = _roles.map((role) => role.id == updated.id ? updated : role).toList());

        if (session.user?.roleId == updated.id) {
          await session.refreshUser();
        }
      } else {
        final created = await createRole(draft);
        if (mounted) setState(() => _roles = [..._roles, created]);
      }

      toast.show('Rol guardado', message: 'Los usuarios con este rol ven los cambios al navegar.', tone: 'success');
      return null;
    } catch (_) {
      return 'No se pudo guardar el rol.';
    }
  }

  void _openDialog(Role? role) {
    RoleDialog.show(context, role: role, onSave: (draft) => _saveRole(role, draft));
  }

  Future<void> _removeRole(Role role) async {
    setState(() => _actionError = null);

    if (_usersWithRole(role) > 0) {
      setState(() => _actionError = 'No se puede eliminar "${role.name}": tiene usuarios asignados. Reasígnalos primero.');
      return;
    }

    final accepted = await confirmAction(context, title: '¿Eliminar el rol "${role.name}"?', confirmLabel: 'Eliminar rol', tone: 'danger');

    if (!accepted) {
      return;
    }

    try {
      await deleteRole(role.id);
      if (mounted) setState(() => _roles = _roles.where((item) => item.id != role.id).toList());
    } catch (_) {
      if (mounted) setState(() => _actionError = 'No se pudo eliminar el rol.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRoles,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminPageHeader(
            section: 'Roles y permisos',
            title: 'Roles y permisos',
            description: 'Cada permiso habilita secciones concretas del portal. Los cambios se aplican a los usuarios con ese rol.',
            actions: [
              BaseButton(
                label: 'Rol',
                icon: Icons.add_rounded,
                variant: 'primary',
                onPressed: _isLoading ? null : () => _openDialog(null),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else ...[
            if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
            for (final role in _roles) ...[
              _RoleCard(
                role: role,
                userCount: _usersWithRole(role),
                onEdit: () => _openDialog(role),
                onRemove: () => _removeRole(role),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.userCount, required this.onEdit, required this.onRemove});

  final Role role;
  final int userCount;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isOwner = role.id == _ownerRoleId;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.name, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                    const SizedBox(height: 2),
                    Text(role.description, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '$userCount ${userCount == 1 ? 'usuario' : 'usuarios'}',
                  style: AppFonts.label(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (role.permissions.isEmpty)
            Text('Sin permisos', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final permission in role.permissions)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(permissionLabel[permission] ?? permission, style: AppFonts.label(fontSize: 13, color: c.primary)),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (isOwner)
            Text('Rol del sistema: no se puede editar ni eliminar.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))
          else ...[
            Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BaseButton(label: 'Editar', onPressed: onEdit),
                const SizedBox(width: 8),
                BaseButton(label: 'Eliminar', variant: 'danger-soft', onPressed: onRemove),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
