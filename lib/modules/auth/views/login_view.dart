import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/http/http_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/landing.dart';
import '../../../router/site_directory.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/base_button.dart';
import '../api.dart';
import '../types.dart';
import '../validation.dart';
import '../widgets/auth_minimal_layout.dart';
import '../widgets/auth_text_field.dart';

typedef _DemoAccount = ({String role, String hint, String email, String password});

const List<_DemoAccount> _demoAccounts = [
  (role: 'Propietario', hint: 'Todo el sistema', email: 'admin@restaurant.com', password: 'admin1234'),
  (role: 'Camarero', hint: 'Pedidos y entregas', email: 'mozo@restaurant.com', password: 'demo1234'),
  (role: 'Cocina', hint: 'Cola de cocina', email: 'cocina@restaurant.com', password: 'demo1234'),
  (role: 'Caja', hint: 'Cuentas y cierre', email: 'caja@restaurant.com', password: 'demo1234'),
];

class LoginView extends StatefulWidget {
  const LoginView({super.key, this.redirect});

  final String? redirect;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _isSubmitting = false;
  bool _rememberSession = true;
  bool _demoOpen = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validateForm() {
    setState(() {
      _emailError = validateEmail(_email.text);
      _passwordError = validatePassword(_password.text);
    });

    return _emailError == null && _passwordError == null;
  }

  /// Completa el formulario con una cuenta demo y entra directamente.
  Future<void> _useDemo(_DemoAccount account) async {
    _email.text = account.email;
    _password.text = account.password;
    await _onSubmit();
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    if (!_validateForm()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final session = context.read<SessionStore>();

    try {
      final authSession = await login(LoginPayload(email: _email.text.trim(), password: _password.text));

      session.setSession(authSession, persist: _rememberSession);
      // La primera vista puede ser una sede: con el directorio cargado, su URL ya lleva el nombre del local.
      await SiteDirectory.ensure();

      if (!mounted) return;
      final redirect = widget.redirect;
      context.go(redirect != null && redirect.startsWith('/') ? redirect : landingRouteFor(authSession.user));
    } catch (error) {
      if (mounted) {
        setState(() => _formError = error is HttpError ? error.message : 'No se pudo iniciar sesión. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AuthMinimalLayout(
      audience: 'restaurant',
      mode: 'login',
      title: 'Bienvenido de nuevo',
      subtitle: 'Entra al portal de tu restaurante.',
      footer: _demoPanel(c),
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
            AuthTextField(
              controller: _email,
              label: 'Correo electrónico',
              type: 'email',
              autofillHints: const [AutofillHints.email],
              placeholder: 'tu@restaurante.com',
              error: _emailError,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _password,
              label: 'Contraseña',
              type: 'password',
              autofillHints: const [AutofillHints.password],
              placeholder: 'Tu contraseña',
              error: _passwordError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _rememberSession = !_rememberSession),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Checkbox(
                      value: _rememberSession,
                      onChanged: (value) => setState(() => _rememberSession = value ?? false),
                    ),
                    Expanded(
                      child: Text('Mantener sesión en este dispositivo', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            BaseButton(
              label: _isSubmitting ? 'Ingresando…' : 'Ingresar',
              variant: 'primary',
              size: 'lg',
              block: true,
              disabled: _isSubmitting,
              onPressed: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoPanel(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _demoOpen = !_demoOpen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Probar con una cuenta demo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _demoOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.expand_more_rounded, size: 20, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_demoOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: [
                  for (final account in _demoAccounts)
                    Material(
                      color: c.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isSubmitting ? null : () => _useDemo(account),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(account.role, style: AppFonts.body(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                              Text(
                                account.hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
