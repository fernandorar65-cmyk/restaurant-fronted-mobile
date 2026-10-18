import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../types.dart';

/// Alta o edición de una categoría de la carta. [onSave] guarda y devuelve un
/// mensaje de error (la hoja sigue abierta) o null (se cierra).
class MenuCategoryDialog extends StatefulWidget {
  const MenuCategoryDialog({super.key, required this.category, required this.onSave});

  final MenuCategory? category;
  final Future<String?> Function(MenuCategoryDraft draft) onSave;

  static Future<void> show(
    BuildContext context, {
    MenuCategory? category,
    required Future<String?> Function(MenuCategoryDraft draft) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MenuCategoryDialog(category: category, onSave: onSave),
    );
  }

  @override
  State<MenuCategoryDialog> createState() => _MenuCategoryDialogState();
}

class _MenuCategoryDialogState extends State<MenuCategoryDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.category?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.category?.description ?? '');
  bool _touched = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _touched = true);

    if (_name.text.trim().isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.onSave(MenuCategoryDraft(name: _name.text.trim(), description: _description.text.trim()));

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return BaseDialogFrame(
      title: widget.category != null ? 'Editar categoría' : 'Nueva categoría',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).maybePop()),
          const Spacer(),
          BaseButton(label: 'Guardar', variant: 'primary', loading: _saving, onPressed: _submit),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nombre',
              errorText: _touched && _name.text.trim().isEmpty ? 'Indica el nombre de la categoría.' : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(fontSize: 13, color: c.error)),
          ],
        ],
      ),
    );
  }
}
