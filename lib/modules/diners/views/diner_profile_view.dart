import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/string.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/diner_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../auth/validation.dart';
import '../../orders/api.dart';
import '../../orders/types.dart';
import '../api.dart';
import '../types.dart';

/// Perfil del comensal (/perfil): datos, preferencias, comunicaciones y contraseña.
class DinerProfileView extends StatefulWidget {
  const DinerProfileView({super.key});

  @override
  State<DinerProfileView> createState() => _DinerProfileViewState();
}

class _DinerProfileViewState extends State<DinerProfileView> {
  CustomerProfile? _profile;
  ({int count, int sites})? _visits;
  bool _isLoading = true;
  String? _loadError;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  String? _birthday;
  List<String> _dietary = [];
  List<String> _allergens = [];
  bool _marketing = false;
  String? _formError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
    _phone.addListener(_refresh);

    if (context.read<DinerStore>().customer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.replace(Uri(path: Routes.dinerAuth, queryParameters: {'redirect': Routes.dinerProfile}).toString());
      });
      return;
    }

    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _isDirty {
    final current = _profile;
    if (current == null) return false;
    final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
    final birthday = (_birthday ?? '').isEmpty ? null : _birthday;

    return _name.text.trim() != current.name ||
        phone != current.phone ||
        birthday != current.birthday ||
        _marketing != current.marketingOptIn ||
        _dietary.join() != current.dietaryPreferences.join() ||
        _allergens.join() != current.allergens.join();
  }

  void _fillForm(CustomerProfile value) {
    _name.text = value.name;
    _phone.text = value.phone ?? '';
    _email.text = value.email;
    _birthday = value.birthday;
    _dietary = [...value.dietaryPreferences];
    _allergens = [...value.allergens];
    _marketing = value.marketingOptIn;
  }

  /// Agrega o quita una opción manteniendo el orden de la lista de opciones.
  List<String> _toggle(List<String> list, String value, List<String> options) {
    final selected = {...list};
    if (!selected.remove(value)) selected.add(value);
    return options.where(selected.contains).toList();
  }

  Future<void> _load() async {
    final customer = context.read<DinerStore>().customer;
    if (customer == null) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([
        fetchCustomerProfile(customer.id),
        fetchAttentionsByCustomer(customer.id).catchError((_) => <Attention>[]),
      ]);
      final loaded = results[0] as CustomerProfile;
      final attentions = results[1] as List<Attention>;
      if (!mounted) return;
      setState(() {
        _profile = loaded;
        _fillForm(loaded);
        _visits = (count: attentions.length, sites: attentions.map((item) => item.restaurantId).toSet().length);
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = errorMessage(error, 'No pudimos cargar tu perfil.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final diner = context.read<DinerStore>();
    final customer = diner.customer;
    setState(() => _formError = validateName(_name.text));

    if (customer == null || _formError != null) return;

    setState(() => _isSaving = true);

    try {
      final saved = await updateCustomerProfile(
        customer.id,
        CustomerProfileDraft(
          name: _name.text,
          phone: _phone.text,
          birthday: _birthday,
          dietaryPreferences: _dietary,
          allergens: _allergens,
          marketingOptIn: _marketing,
        ),
      );
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _fillForm(saved);
      });
      diner.setCustomer(DinerCustomer(id: saved.id, name: saved.name, email: saved.email));
      context.read<ToastStore>().show('Perfil actualizado', tone: 'success');
    } catch (error) {
      if (mounted) setState(() => _formError = errorMessage(error, 'No se pudo guardar tu perfil.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBirthday() async {
    final initial = DateTime.tryParse(_birthday ?? '') ?? DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Cumpleaños',
    );
    if (picked != null && mounted) {
      setState(() => _birthday = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _logout() {
    context.read<DinerStore>().setCustomer(null);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_isLoading) {
      return const SingleChildScrollView(padding: EdgeInsets.all(16), child: SkeletonBlock(rows: 4));
    }

    if (_loadError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(16)),
            child: Text(_loadError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
          ),
          const SizedBox(height: 12),
          BaseButton(label: 'Reintentar', onPressed: _load),
        ],
      );
    }

    final profile = _profile;
    if (profile == null) return const SizedBox.shrink();

    final cardDecoration = BoxDecoration(
      color: c.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
    );

    Widget card(List<Widget> children) => Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    Widget fieldLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurfaceVariant)),
        );

    Widget optionChip(String option, bool selected, Color selectedBg, Color selectedFg, VoidCallback onTap) => Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? selectedBg : c.surfaceContainer,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Text(option, style: AppFonts.label(fontSize: 14, color: selected ? selectedFg : c.onSurfaceVariant)),
              ),
            ),
          ),
        );

    final visits = _visits;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Cabecera.
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: Text(getInitials(profile.name), style: AppFonts.headline(fontSize: 20, color: c.onPrimary)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLIENTE', style: AppFonts.eyebrow(color: c.tertiary)),
                    Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.title(fontSize: 24, color: c.heading)),
                    Text(
                      profile.createdAt != null ? '${profile.email} · Desde ${formatMonthYear(profile.createdAt!)}' : profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Actividad.
          if (visits != null) ...[
            Row(
              children: [
                for (final (index, stat) in [
                  (value: visits.count, label: visits.count == 1 ? 'Visita' : 'Visitas'),
                  (value: visits.sites, label: visits.sites == 1 ? 'Restaurante' : 'Restaurantes'),
                ].indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${stat.value}', style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
                          Text(stat.label, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go(Routes.dinerVisits),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Text('Ver mis visitas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primaryInk))),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: c.primaryInk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Datos personales.
          card([
            Text('Datos personales', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
            const SizedBox(height: 16),
            fieldLabel('Nombre'),
            TextField(
              controller: _name,
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(fillColor: c.surface),
            ),
            const SizedBox(height: 16),
            fieldLabel('Correo'),
            Opacity(
              opacity: 0.7,
              child: TextField(
                controller: _email,
                enabled: false,
                decoration: InputDecoration(fillColor: c.surface),
              ),
            ),
            const SizedBox(height: 16),
            fieldLabel('Teléfono'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(fillColor: c.surface, hintText: '+51 999 999 999'),
            ),
            const SizedBox(height: 16),
            fieldLabel('Cumpleaños'),
            InkWell(
              onTap: _pickBirthday,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  fillColor: c.surface,
                  suffixIcon: (_birthday ?? '').isEmpty
                      ? Icon(Icons.calendar_today_outlined, size: 18, color: c.outline)
                      : IconButton(
                          tooltip: 'Quitar fecha',
                          icon: Icon(Icons.close_rounded, size: 18, color: c.outline),
                          onPressed: () => setState(() => _birthday = null),
                        ),
                ),
                child: Text(
                  (_birthday ?? '').isEmpty
                      ? 'Elegir fecha'
                      : DateFormat("d 'de' MMMM 'de' y", 'es').format(DateTime.tryParse(_birthday!) ?? DateTime(1990)),
                  style: TextStyle(fontSize: 14, color: (_birthday ?? '').isEmpty ? c.outline : c.onSurface),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Preferencias.
          card([
            Text('Preferencias alimentarias', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
            Text('Te ayudarán a encontrar platos para ti.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in DIETARY_PREFERENCES)
                  optionChip(
                    option,
                    _dietary.contains(option),
                    c.primary,
                    c.onPrimary,
                    () => setState(() => _dietary = _toggle(_dietary, option, DIETARY_PREFERENCES)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Alergias', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
            Text('Avisa al restaurante de lo que no puedes comer.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in ALLERGEN_OPTIONS)
                  optionChip(
                    option,
                    _allergens.contains(option),
                    c.errorContainer,
                    c.onErrorContainer,
                    () => setState(() => _allergens = _toggle(_allergens, option, ALLERGEN_OPTIONS)),
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 20),

          // Comunicaciones.
          Container(
            decoration: cardDecoration,
            child: SwitchListTile(
              value: _marketing,
              onChanged: (value) => setState(() => _marketing = value),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text('Promociones y novedades', style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
              subtitle: Text('Recibe ofertas de los restaurantes que visitas.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            ),
          ),
          const SizedBox(height: 20),

          if (_formError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_formError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
            ),
            const SizedBox(height: 12),
          ],
          BaseButton(
            label: 'Guardar cambios',
            variant: 'primary',
            size: 'lg',
            block: true,
            loading: _isSaving,
            disabled: !_isDirty,
            onPressed: _save,
          ),
          const SizedBox(height: 20),

          // Seguridad.
          card([
            Text('Seguridad', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
            const SizedBox(height: 16),
            _ChangePasswordForm(
              submit: (current, next) async {
                final customer = context.read<DinerStore>().customer;
                if (customer != null) {
                  await changeCustomerPassword(customer.id, current, next);
                }
              },
            ),
          ]),
          const SizedBox(height: 20),
          BaseButton(label: 'Cerrar sesión', variant: 'danger-soft', size: 'lg', block: true, onPressed: _logout),
        ],
      ),
    );
  }
}

/// Cambio de contraseña (equivale a ChangePasswordForm.vue).
class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm({required this.submit});

  final Future<void> Function(String currentPassword, String nextPassword) submit;

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _success = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() {
      _success = false;
      _error = (_current.text.isEmpty ? 'Ingresa tu contraseña actual.' : null) ??
          validatePassword(_next.text) ??
          (_next.text != _confirm.text ? 'Las contraseñas nuevas no coinciden.' : null) ??
          (_next.text == _current.text ? 'La nueva contraseña debe ser distinta a la actual.' : null);
    });

    if (_error != null) return;

    setState(() => _isSaving = true);

    try {
      await widget.submit(_current.text, _next.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() => _success = true);
    } catch (caught) {
      if (mounted) setState(() => _error = errorMessage(caught, 'No se pudo cambiar la contraseña.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget field(String label, TextEditingController controller, List<String> hints) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurfaceVariant)),
              ),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: hints,
                decoration: InputDecoration(fillColor: c.surface),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field('Contraseña actual', _current, const [AutofillHints.password]),
        field('Nueva contraseña', _next, const [AutofillHints.newPassword]),
        field('Repite la nueva', _confirm, const [AutofillHints.newPassword]),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
          )
        else if (_success)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: c.successContainer, borderRadius: BorderRadius.circular(12)),
            child: Text('Contraseña actualizada.', style: TextStyle(fontSize: 14, color: c.onSuccessContainer)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: BaseButton(label: 'Cambiar contraseña', loading: _isSaving, onPressed: _onSubmit),
        ),
      ],
    );
  }
}
