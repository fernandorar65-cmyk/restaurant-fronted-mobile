import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../types.dart';

/// Alta o edición de un producto de la carta. [onSave] guarda y devuelve un
/// mensaje de error (la hoja sigue abierta) o null (se cierra).
///
/// La foto se indica con una URL (o un data URL ya guardado): la app no incluye selector de archivos.
class MenuProductDialog extends StatefulWidget {
  const MenuProductDialog({
    super.key,
    required this.product,
    required this.categories,
    required this.defaultCategoryId,
    required this.currency,
    required this.onSave,
  });

  final MenuProduct? product;
  final List<MenuCategory> categories;
  final String? defaultCategoryId;
  final String currency;
  final Future<String?> Function(MenuProductDraft draft) onSave;

  static Future<void> show(
    BuildContext context, {
    MenuProduct? product,
    required List<MenuCategory> categories,
    String? defaultCategoryId,
    required String currency,
    required Future<String?> Function(MenuProductDraft draft) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MenuProductDialog(
        product: product,
        categories: categories,
        defaultCategoryId: defaultCategoryId,
        currency: currency,
        onSave: onSave,
      ),
    );
  }

  @override
  State<MenuProductDialog> createState() => _MenuProductDialogState();
}

String _formatNumber(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

class _MenuProductDialogState extends State<MenuProductDialog> {
  MenuProduct? get _product => widget.product;

  late final TextEditingController _name = TextEditingController(text: _product?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: _product?.description ?? '');
  late final TextEditingController _price = TextEditingController(text: _formatNumber(_product?.price ?? 0));
  late final TextEditingController _imageUrl = TextEditingController(text: _product?.imageUrl ?? '');
  late final TextEditingController _tags = TextEditingController(text: _product?.tags.join(', ') ?? '');
  late final TextEditingController _allergens = TextEditingController(text: _product?.allergens.join(', ') ?? '');
  late final TextEditingController _ingredients = TextEditingController(text: _product?.ingredients.join(', ') ?? '');
  late final TextEditingController _portion = TextEditingController(text: _product?.portion ?? '');
  late final TextEditingController _presentation = TextEditingController(text: _product?.presentation ?? '');
  late final TextEditingController _longDescription = TextEditingController(text: _product?.longDescription ?? '');
  late final TextEditingController _prepMinutes = TextEditingController(text: _product?.prepMinutes?.toString() ?? '');
  late String _categoryId = _product?.categoryId ??
      widget.defaultCategoryId ??
      (widget.categories.isNotEmpty ? widget.categories.first.id : '');
  late bool _isAvailable = _product?.isAvailable ?? true;
  late bool _isActive = _product?.isActive ?? true;
  bool _touched = false;
  bool _saving = false;
  String? _error;

  List<TextEditingController> get _controllers => [
        _name,
        _description,
        _price,
        _imageUrl,
        _tags,
        _allergens,
        _ingredients,
        _portion,
        _presentation,
        _longDescription,
        _prepMinutes,
      ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _parseList(String value) => value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();

  Future<void> _submit() async {
    setState(() => _touched = true);

    if (_name.text.trim().isEmpty || _categoryId.isEmpty) return;

    final prep = double.tryParse(_prepMinutes.text.trim().replaceAll(',', '.')) ?? 0;
    final draft = MenuProductDraft(
      categoryId: _categoryId,
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0,
      imageUrl: _imageUrl.text.trim(),
      isActive: _isActive,
      isAvailable: _isAvailable,
      tags: _parseList(_tags.text),
      allergens: _parseList(_allergens.text),
      ingredients: _parseList(_ingredients.text),
      portion: _portion.text.trim(),
      presentation: _presentation.text.trim(),
      longDescription: _longDescription.text.trim(),
      prepMinutes: prep > 0 ? prep.round() : null,
    );

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.onSave(draft);

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
    const gap = SizedBox(height: 16);
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return BaseDialogFrame(
      title: _product != null ? 'Editar producto' : 'Nuevo producto',
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
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nombre',
              errorText: _touched && _name.text.trim().isEmpty ? 'Indica el nombre del producto.' : null,
            ),
          ),
          gap,
          Row(
            children: [
              _ImagePreview(url: _imageUrl.text.trim()),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _imageUrl,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Foto (URL)', hintText: 'https://…'),
                ),
              ),
            ],
          ),
          gap,
          TextField(controller: _description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Descripción')),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimal,
                  decoration: InputDecoration(labelText: 'Precio (${widget.currency})'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: widget.categories.any((category) => category.id == _categoryId) ? _categoryId : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    errorText: _touched && _categoryId.isEmpty ? 'Elige una categoría.' : null,
                  ),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem(value: category.id, child: Text(category.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value ?? _categoryId),
                ),
              ),
            ],
          ),
          gap,
          TextField(
            controller: _tags,
            decoration: const InputDecoration(labelText: 'Etiquetas (separadas por coma)', hintText: 'Vegetariano, Recomendado chef'),
          ),
          gap,
          TextField(
            controller: _allergens,
            decoration: const InputDecoration(labelText: 'Alérgenos (separados por coma)', hintText: 'Gluten, Lácteos'),
          ),
          gap,
          TextField(
            controller: _ingredients,
            decoration: const InputDecoration(
              labelText: 'Ingredientes (separados por coma)',
              hintText: 'Jamón ibérico, Leche entera, Harina de trigo',
            ),
          ),
          gap,
          TextField(
            controller: _longDescription,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Descripción larga (detalle del plato)',
              hintText: 'Origen de los ingredientes, técnica, sabor y con qué combina.',
              alignLabelWithHint: true,
            ),
          ),
          gap,
          TextField(
            controller: _prepMinutes,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: const InputDecoration(labelText: 'Tiempo de preparación (minutos)', hintText: '15'),
          ),
          gap,
          TextField(
            controller: _portion,
            decoration: const InputDecoration(labelText: 'Porción', hintText: '6 unidades · Para compartir · 400 g'),
          ),
          gap,
          TextField(
            controller: _presentation,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Presentación',
              hintText: 'Cómo llega a la mesa: emplatado, acompañamientos, recomendaciones.',
              alignLabelWithHint: true,
            ),
          ),
          gap,
          Container(
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value ?? _isActive),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Activo'),
                  subtitle: const Text('Se muestra en la carta. Desmarca para ocultarlo sin borrarlo.'),
                ),
                CheckboxListTile(
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value ?? _isAvailable),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Disponible'),
                  subtitle: const Text('Se puede pedir. Si no, aparece como "Agotado".'),
                ),
              ],
            ),
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

/// Miniatura de la foto: URL de red o data URL (fotos subidas desde la web).
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final placeholder = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: Text('Sin foto', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
    );

    if (url.isEmpty) return placeholder;

    Widget image;

    if (url.startsWith('data:')) {
      final Uint8List bytes;
      try {
        bytes = UriData.parse(url).contentAsBytes();
      } catch (_) {
        return placeholder;
      }
      image = Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
    } else {
      image = Image.network(url, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
    }

    return Semantics(
      image: true,
      label: 'Vista previa',
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
    );
  }
}
