import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/navigation/theme_menu.dart';
import '../../auth/validation.dart';
import '../../orders/api.dart';
import '../api.dart';

/// Ingreso / registro del comensal (/customer/auth/login y /customer/auth/register).
/// Pantalla completa fuera de la barra del comensal.
class DinerAuthView extends StatefulWidget {
  const DinerAuthView({super.key, required this.register, this.redirect});

  final bool register;
  final String? redirect;

  @override
  State<DinerAuthView> createState() => _DinerAuthViewState();
}

class _DinerAuthViewState extends State<DinerAuthView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _isSubmitting = false;

  @override
  void didUpdateWidget(covariant DinerAuthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar de pestaña se limpian los errores del otro formulario.
    if (oldWidget.register != widget.register) {
      _formError = null;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _redirectTarget {
    final value = widget.redirect;
    return value != null && value.startsWith('/') ? value : null;
  }

  void _goBack() {
    final diner = context.read<DinerStore>();
    context.go(_redirectTarget ?? (diner.isReadyToOrder ? diner.menuRoute : Routes.dinerProfile));
  }

  Future<void> _submit() async {
    setState(() {
      _formError = null;
      _nameError = widget.register ? validateName(_name.text) : null;
      _emailError = validateEmail(_email.text);
      _passwordError = validatePassword(_password.text);
    });

    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    final diner = context.read<DinerStore>();

    try {
      final customer = widget.register
          ? await registerCustomer(_name.text, _email.text, _password.text)
          : await loginCustomer(_email.text, _password.text);
      diner.setCustomer(customer);

      if (diner.hasTable) {
        diner.confirmTable();
      }

      if (mounted) _goBack();
    } catch (error) {
      if (mounted) setState(() => _formError = errorMessage(error, 'No se pudo completar. Inténtalo de nuevo.'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _continueAsGuest() {
    context.read<DinerStore>().confirmTable();
    _goBack();
  }

  /// Se conserva ?redirect al cambiar de pestaña.
  String _withRedirect(String path) =>
      widget.redirect == null ? path : Uri(path: path, queryParameters: {'redirect': widget.redirect}).toString();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();
    final customer = diner.customer;

    // Ya tiene sesión de cliente.
    if (customer != null) {
      return _AuthLayout(
        register: widget.register,
        title: 'Hola, ${customer.name}',
        subtitle: customer.email,
        hideSwitches: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BaseButton(
              label: 'Ir a mi perfil',
              variant: 'primary',
              size: 'lg',
              block: true,
              onPressed: () => context.go(Routes.dinerProfile),
            ),
            const SizedBox(height: 8),
            BaseButton(label: 'Cerrar sesión', size: 'lg', block: true, onPressed: () => diner.setCustomer(null)),
          ],
        ),
      );
    }

    return _AuthLayout(
      register: widget.register,
      title: widget.register ? 'Crea tu cuenta' : 'Ingresa a tu cuenta',
      subtitle: 'Guarda tus visitas, preferencias y pedidos. También puedes pedir como invitado.',
      loginPath: _withRedirect(Routes.dinerAuth),
      registerPath: _withRedirect(Routes.dinerRegister),
      footer: Text(
        'Demo: cliente@demo.com / cliente1234',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_formError != null) ...[
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_formError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.register) ...[
              _AuthTextField(
                controller: _name,
                label: 'Nombre',
                placeholder: 'Tu nombre',
                error: _nameError,
                autofillHints: const [AutofillHints.name],
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 16),
            ],
            _AuthTextField(
              controller: _email,
              label: 'Correo electrónico',
              placeholder: 'tu@correo.com',
              error: _emailError,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              controller: _password,
              label: 'Contraseña',
              placeholder: widget.register ? 'Mínimo 8 caracteres' : 'Tu contraseña',
              error: _passwordError,
              password: true,
              autofillHints: [widget.register ? AutofillHints.newPassword : AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            BaseButton(
              label: _isSubmitting ? 'Un momento…' : (widget.register ? 'Crear cuenta' : 'Ingresar'),
              variant: 'primary',
              size: 'lg',
              block: true,
              disabled: _isSubmitting,
              onPressed: _submit,
            ),
            if (diner.hasTable)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.primaryInk),
                onPressed: _continueAsGuest,
                child: const Text('Prefiero seguir como invitado', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de acceso (equivale a AuthMinimalLayout.vue con audience="customer").
class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.register,
    required this.title,
    this.subtitle,
    this.hideSwitches = false,
    this.loginPath,
    this.registerPath,
    this.footer,
    required this.child,
  });

  final bool register;
  final String title;
  final String? subtitle;
  final bool hideSwitches;
  final String? loginPath;
  final String? registerPath;
  final Widget? footer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget tab(String label, bool active, String? path) => Expanded(
          child: Material(
            color: active ? c.surfaceContainerLowest : Colors.transparent,
            elevation: active ? 1 : 0,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: active || path == null ? null : () => context.replace(path),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Text(label, style: AppFonts.label(fontSize: 14, color: active ? c.onSurface : c.onSurfaceVariant)),
              ),
            ),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'RentaSol, ir al inicio',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => context.go(Routes.home),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.menu_book_outlined, size: 20, color: c.onPrimary),
                            ),
                            const SizedBox(width: 10),
                            Text('RentaSol', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const ThemeMenu(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(999)),
                            child: Text('Cliente', style: AppFonts.label(fontSize: 12, color: c.onPrimaryFixed)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(title, textAlign: TextAlign.center, style: AppFonts.title(fontSize: 30, color: c.heading)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 24),
                        if (!hideSwitches) ...[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                tab('Ingresar', !register, loginPath),
                                const SizedBox(width: 4),
                                tab('Crear cuenta', register, registerPath),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        child,
                        if (!hideSwitches) ...[
                          const SizedBox(height: 20),
                          Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('¿Tienes un restaurante?', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                              TextButton(
                                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.primaryInk),
                                onPressed: () => context.go(register ? Routes.register : Routes.login),
                                child: const Text('Entra como dueño', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                        if (footer != null) ...[const SizedBox(height: 16), footer!],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de los formularios de acceso: etiqueta, input y error (equivale a AuthTextField.vue).
class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    this.placeholder,
    this.error,
    this.password = false,
    this.autofillHints,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final String? error;
  final bool password;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurface)),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: widget.password && !_visible,
          autofillHints: widget.autofillHints,
          keyboardType: widget.keyboardType,
          autocorrect: !widget.password && widget.keyboardType != TextInputType.emailAddress,
          enableSuggestions: !widget.password,
          textInputAction: widget.onSubmitted != null ? TextInputAction.done : TextInputAction.next,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(fontSize: 16, color: c.onSurface),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            fillColor: c.surfaceContainerLowest,
            errorText: widget.error,
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.outline),
                    onPressed: () => setState(() => _visible = !_visible),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
