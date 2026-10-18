import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../widgets/admin_form.dart';

/// Datos generales de la organización (equivale a OrganizationSettingsView.vue).
class OrganizationSettingsView extends StatefulWidget {
  const OrganizationSettingsView({super.key});

  @override
  State<OrganizationSettingsView> createState() => _OrganizationSettingsViewState();
}

class _OrganizationSettingsViewState extends State<OrganizationSettingsView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  Organization? _organization;
  String? _loadError;
  String? _formError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _saveSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadOrganization();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final organizations = await fetchOrganizations();
      _organization = organizations.firstOrNull;
      _name.text = _organization?.name ?? '';
      _code.text = _organization?.code ?? '';
    } catch (error) {
      _loadError = errorText(error, 'No se pudo cargar la organización.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final organization = _organization;

    if (organization == null) {
      return;
    }

    // Equivale a los campos `required` del formulario web.
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() => _formError = 'Completa el nombre y el código de la organización.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _saveSuccess = false;
      _formError = null;
    });

    try {
      _organization = await updateOrganization(organization.id, OrganizationDraft(name: _name.text.trim(), code: _code.text.trim()));
      _saveSuccess = true;
    } catch (error) {
      _loadError = errorText(error, 'No se pudo guardar la configuración.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return RefreshIndicator(
      onRefresh: _loadOrganization,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go(Routes.adminHome),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('ADMINISTRACIÓN', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(color: c.outlineVariant))),
              Text('CONFIGURACIÓN', style: AppFonts.eyebrow(color: c.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Configuración de organización', style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
          const SizedBox(height: 4),
          Text('Datos generales de la cadena.', style: TextStyle(fontSize: 15, color: c.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else
            AdminCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre de la organización')),
                  fieldGap,
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Código'),
                    onSubmitted: (_) => _save(),
                  ),
                  if (_formError != null) ...[fieldGap, InlineAlert(_formError!)],
                  if (_saveSuccess) ...[fieldGap, const InlineAlert('Configuración guardada.', tone: 'success')],
                  const SizedBox(height: 20),
                  BaseButton(
                    label: _isSaving ? 'Guardando…' : 'Guardar cambios',
                    variant: 'primary',
                    block: true,
                    disabled: _isSaving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
