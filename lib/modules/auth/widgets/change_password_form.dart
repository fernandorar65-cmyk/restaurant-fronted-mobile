import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_button.dart';
import '../../orders/api.dart';
import '../validation.dart';

/// Formulario de cambio de contraseña, común al perfil del cliente y al del restaurante.
class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({super.key, required this.submit});

  final Future<void> Function(String currentPassword, String nextPassword) submit;

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
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
    FocusScope.of(context).unfocus();
    final current = _current.text;
    final next = _next.text;

    setState(() {
      _success = false;
      _error = (current.isEmpty ? 'Ingresa tu contraseña actual.' : null) ??
          validatePassword(next) ??
          (next != _confirm.text ? 'Las contraseñas nuevas no coinciden.' : null) ??
          (next == current ? 'La nueva contraseña debe ser distinta a la actual.' : null);
    });

    if (_error != null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.submit(current, next);
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) setState(() => _success = true);
    } catch (caught) {
      if (mounted) setState(() => _error = errorMessage(caught, 'No se pudo cambiar la contraseña.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PasswordField(label: 'Contraseña actual', controller: _current, autofillHints: const [AutofillHints.password]),
          const SizedBox(height: 12),
          _PasswordField(label: 'Nueva contraseña', controller: _next, autofillHints: const [AutofillHints.newPassword]),
          const SizedBox(height: 12),
          _PasswordField(
            label: 'Repite la nueva',
            controller: _confirm,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _onSubmit(),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            _Message(text: _error!, background: c.errorContainer, foreground: c.onErrorContainer)
          else if (_success)
            _Message(text: 'Contraseña actualizada.', background: c.successContainer, foreground: c.onSuccessContainer),
          if (_error != null || _success) const SizedBox(height: 12),
          BaseButton(label: 'Cambiar contraseña', loading: _isSaving, onPressed: _onSubmit),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.background, required this.foreground});

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 14, color: foreground)),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.label, required this.controller, this.autofillHints, this.onSubmitted});

  final String label;
  final TextEditingController controller;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurfaceVariant)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
          decoration: const InputDecoration(constraints: BoxConstraints(minHeight: 44)),
        ),
      ],
    );
  }
}
