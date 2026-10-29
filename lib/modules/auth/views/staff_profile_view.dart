import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/string.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../administration/admin_labels.dart';
import '../../orders/api.dart';
import '../api.dart';
import '../permissions.dart';
import '../types.dart';
import '../validation.dart';
import '../widgets/change_password_form.dart';

class StaffProfileView extends StatefulWidget {
  const StaffProfileView({super.key});

  @override
  State<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  StaffProfile? _profile;
  bool _isLoading = true;
  String? _loadError;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _jobTitle = TextEditingController();
  String? _formError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _phone, _jobTitle]) {
      controller.addListener(_onFormChanged);
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _jobTitle.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  bool get _isOwner => _profile?.roleName == 'Propietario';

  String? _clean(String value) => value.trim().isEmpty ? null : value.trim();

  bool get _isDirty {
    final current = _profile;
    return current != null &&
        (_name.text.trim() != current.name || _clean(_phone.text) != current.phone || _clean(_jobTitle.text) != current.jobTitle);
  }

  /// Permisos en el orden del catálogo, para que se lean siempre igual.
  List<Permission> get _grantedPermissions =>
      permissionsList.where((permission) => _profile?.permissions.contains(permission) ?? false).toList();

  void _fillForm(StaffProfile value) {
    _name.text = value.name;
    _phone.text = value.phone ?? '';
    _jobTitle.text = value.jobTitle ?? '';
  }

  String _areaLabel(String area) => employeeAreaLabel[area] ?? area;

  String _statusLabel(String status) => employeeStatusLabel[status] ?? status;

  Future<void> _load() async {
    final user = context.read<SessionStore>().user;

    if (user == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await fetchStaffProfile(user.id);
      if (!mounted) return;
      _profile = profile;
      _fillForm(profile);
    } catch (error) {
      _loadError = errorMessage(error, 'No pudimos cargar tu perfil.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final session = context.read<SessionStore>();
    final toast = context.read<ToastStore>();
    setState(() => _formError = validateName(_name.text));

    final user = session.user;

    if (user == null || _formError != null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await updateStaffProfile(user.id, StaffProfileDraft(name: _name.text, phone: _phone.text, jobTitle: _jobTitle.text));
      // El nombre también aparece en el encabezado y el menú lateral.
      await session.refreshUser();
      await _load();
      toast.show('Perfil actualizado', tone: 'success');
    } catch (error) {
      if (mounted) setState(() => _formError = errorMessage(error, 'No se pudo guardar tu perfil.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword(String current, String next) async {
    final user = context.read<SessionStore>().user;

    if (user != null) {
      await changeStaffPassword(user.id, current, next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = _profile;

    Widget body;

    if (_isLoading) {
      body = const SkeletonBlock(rows: 5);
    } else if (_loadError != null) {
      body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(16)),
        child: Text(_loadError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
      );
    } else if (profile != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(c, profile),
          const SizedBox(height: 16),
          _contactCard(c, profile),
          const SizedBox(height: 16),
          _Card(
            children: [
              _cardTitle(c, 'Seguridad'),
              ChangePasswordForm(submit: _changePassword),
            ],
          ),
          const SizedBox(height: 16),
          _sitesCard(c, profile),
          if (profile.employee != null) ...[
            const SizedBox(height: 16),
            _employeeCard(c, profile.employee!),
          ],
          const SizedBox(height: 16),
          _permissionsCard(c),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: body,
      ),
    );
  }

  Widget _cardTitle(AppColors c, String text) => Text(text, style: AppFonts.headline(fontSize: 18, color: c.onSurface));

  Widget _header(AppColors c, StaffProfile profile) {
    return _Card(
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(16)),
              child: ExcludeSemantics(
                child: Text(getInitials(profile.name), style: AppFonts.headline(fontSize: 24, color: c.onPrimary)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_isOwner ? 'Dueño de restaurante' : 'Personal del restaurante').toUpperCase(),
                    style: AppFonts.eyebrow(color: c.tertiary),
                  ),
                  Text(
                    profile.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.title(fontSize: 24, color: c.heading, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${profile.jobTitle ?? profile.roleName ?? 'Sin cargo'} · ${profile.email}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.roleName != null || profile.createdAt != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.roleName != null) _Pill(label: 'Rol: ${profile.roleName}', background: c.primaryFixed, foreground: c.onPrimaryFixed),
              if (profile.createdAt != null)
                _Pill(
                  label: 'Desde ${formatMonthYear(profile.createdAt!)}',
                  background: c.surfaceContainer,
                  foreground: c.onSurfaceVariant,
                ),
            ],
          ),
      ],
    );
  }

  Widget _contactCard(AppColors c, StaffProfile profile) {
    return _Card(
      children: [
        _cardTitle(c, 'Datos de contacto'),
        _Field(
          label: 'Nombre',
          child: TextField(
            controller: _name,
            autofillHints: const [AutofillHints.name],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
        ),
        _Field(
          label: 'Cargo',
          child: TextField(
            controller: _jobTitle,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Ej: Fundador y propietario'),
          ),
        ),
        _Field(
          label: 'Teléfono',
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
          ),
        ),
        _Field(
          label: 'Correo de acceso',
          child: Opacity(
            opacity: 0.7,
            child: TextFormField(
              key: ValueKey(profile.email),
              initialValue: profile.email,
              enabled: false,
            ),
          ),
        ),
        if (_formError != null)
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_formError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: BaseButton(
            label: 'Guardar cambios',
            variant: 'primary',
            loading: _isSaving,
            disabled: !_isDirty,
            onPressed: _save,
          ),
        ),
      ],
    );
  }

  Widget _sitesCard(AppColors c, StaffProfile profile) {
    return _Card(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: _cardTitle(c, _isOwner ? 'Mis restaurantes' : 'Mis sedes')),
            if (profile.allRestaurants) Text('Toda la organización', style: AppFonts.label(fontSize: 12, color: c.onSurfaceVariant)),
          ],
        ),
        if (profile.restaurants.isEmpty)
          Text('Sin sedes asignadas.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))
        else
          Column(
            children: [
              for (final site in profile.restaurants)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(Routes.siteDashboard(site.slug)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            site.imageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                Container(width: 44, height: 44, color: c.surfaceContainer, child: Icon(Icons.storefront_outlined, color: c.outline)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                site.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                              ),
                              Text(site.city, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: c.outline),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _employeeCard(AppColors c, StaffProfileEmployee employee) {
    Widget item(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
          ],
        );

    final items = [
      item('Área', _areaLabel(employee.area)),
      item('Estado', _statusLabel(employee.status)),
      if (employee.restaurantName != null) item('Sede', employee.restaurantName!),
      if (employee.hiredAt != null) item('Ingreso', formatMonthYear(employee.hiredAt!)),
    ];

    return _Card(
      children: [
        _cardTitle(c, 'Ficha de empleado'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final child in items) SizedBox(width: width, child: child)],
            );
          },
        ),
      ],
    );
  }

  Widget _permissionsCard(AppColors c) {
    final granted = _grantedPermissions;

    return _Card(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(c, 'Qué puedes hacer'),
            Text('Lo define tu rol; lo cambia un administrador.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          ],
        ),
        if (granted.isEmpty)
          Text('Tu rol aún no tiene permisos.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final permission in granted)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: c.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(permissionLabel[permission] ?? permission, style: TextStyle(fontSize: 14, color: c.onSurface)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 16),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppFonts.label(fontSize: 12, color: foreground)),
    );
  }
}
