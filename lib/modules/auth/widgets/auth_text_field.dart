import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Campo de los formularios de acceso (cliente y restaurante): etiqueta, input y error.
/// type: 'text' | 'email' | 'password'
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.type = 'text',
    this.autofillHints,
    this.error,
    this.placeholder,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String type;
  final Iterable<String>? autofillHints;
  final String? error;
  final String? placeholder;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPassword = widget.type == 'password';
    final hasError = widget.error != null;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: width));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurface)),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: isPassword && !_isPasswordVisible,
          autocorrect: !isPassword && widget.type != 'email',
          enableSuggestions: !isPassword,
          keyboardType: widget.type == 'email' ? TextInputType.emailAddress : TextInputType.text,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(fontSize: 16, color: c.onSurface),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(color: c.outline),
            filled: true,
            fillColor: c.surfaceContainerLowest,
            constraints: const BoxConstraints(minHeight: 48),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: border(hasError ? c.error : c.outlineVariant.withValues(alpha: 0.7)),
            focusedBorder: border(hasError ? c.error : c.primaryInk, 2),
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _isPasswordVisible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.outline),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  )
                : null,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(widget.error!, style: TextStyle(fontSize: 14, color: c.error)),
        ],
      ],
    );
  }
}
