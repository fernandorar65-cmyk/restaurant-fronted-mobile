import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/http/http_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../router/landing.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/base_button.dart';
import '../api.dart';
import '../types.dart';
import '../validation.dart';
import '../widgets/auth_minimal_layout.dart';
import '../widgets/auth_text_field.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validateForm() {
    setState(() {
      _nameError = validateName(_name.text);
      _emailError = validateEmail(_email.text);
      _passwordError = validatePassword(_password.text);
    });

    return _nameError == null && _emailError == null && _passwordError == null;
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
      final authSession = await register(
        RegisterPayload(name: _name.text.trim(), email: _email.text.trim(), password: _password.text),
      );

      session.setSession(authSession);
      if (mounted) context.go(landingRouteFor(authSession.user));
    } catch (error) {
      if (mounted) {
        setState(() => _formError = error is HttpError ? error.message : 'No se pudo crear la cuenta. Inténtalo de nuevo.');
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
      mode: 'register',
      title: 'Registra tu restaurante',
      subtitle: 'Crea tu cuenta de dueño para empezar.',
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
              controller: _name,
              label: 'Nombre',
              autofillHints: const [AutofillHints.name],
              placeholder: 'Ana Pérez',
              error: _nameError,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
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
              autofillHints: const [AutofillHints.newPassword],
              placeholder: 'Mínimo 8 caracteres',
              error: _passwordError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 16),
            BaseButton(
              label: _isSubmitting ? 'Creando cuenta…' : 'Crear cuenta',
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
}
