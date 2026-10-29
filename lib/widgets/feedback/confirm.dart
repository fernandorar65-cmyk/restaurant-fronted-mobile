import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../base/base_button.dart';

/// Confirmación con el diseño de la app (equivale a `useConfirmStore().ask(...)`).
/// tone: 'primary' | 'danger' (para acciones que borran o no se pueden deshacer).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  String tone = 'primary',
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final c = dialogContext.colors;

      return AlertDialog(
        title: Text(title, style: AppFonts.title(fontSize: 20, color: c.heading)),
        content: message == null ? null : Text(message, style: TextStyle(color: c.onSurfaceVariant)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          BaseButton(label: cancelLabel, variant: 'ghost', onPressed: () => Navigator.of(dialogContext).pop(false)),
          BaseButton(
            label: confirmLabel,
            variant: tone == 'danger' ? 'danger' : 'primary',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );

  return accepted ?? false;
}
