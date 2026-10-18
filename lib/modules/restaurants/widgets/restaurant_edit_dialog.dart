import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../api.dart';
import '../site_labels.dart';
import '../types.dart';

const Map<RestaurantCategory, String> _categoryLabels = {
  'fine-dining': 'Alta cocina',
  'bistro': 'Cava y bistró',
  'lab': 'I+D y laboratorio',
};

const Map<RestaurantOperationalStatus, String> _statusLabels = {
  'active': 'Activo',
  'inactive': 'Inactivo',
  'suspended': 'Suspendido',
};

const int _maxFloors = 10;
const String _defaultImageUrl =
    'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&h=400&fit=crop&auto=format&q=70';

/// Alta (restaurant == null) o edición de una sede.
///
/// Con [onSave], la hoja guarda y queda abierta si devuelve un mensaje de error; sin él,
/// `show` devuelve el borrador y quien llama se encarga de guardar.
class RestaurantEditDialog extends StatefulWidget {
  const RestaurantEditDialog({super.key, required this.restaurant, this.onSave});

  /// null = alta de una sede nueva.
  final RestaurantSite? restaurant;
  final Future<String?> Function(NewRestaurantDraft draft)? onSave;

  static Future<NewRestaurantDraft?> show(
    BuildContext context, {
    RestaurantSite? restaurant,
    Future<String?> Function(NewRestaurantDraft draft)? onSave,
  }) {
    return showModalBottomSheet<NewRestaurantDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => RestaurantEditDialog(restaurant: restaurant, onSave: onSave),
    );
  }

  @override
  State<RestaurantEditDialog> createState() => _RestaurantEditDialogState();
}

class _RestaurantEditDialogState extends State<RestaurantEditDialog> {
  RestaurantSite? get _site => widget.restaurant;

  late final TextEditingController _code = TextEditingController(text: _site?.code ?? '');
  late final TextEditingController _name = TextEditingController(text: _site?.name ?? '');
  late final TextEditingController _city = TextEditingController(text: _site?.city ?? '');
  late final TextEditingController _address = TextEditingController(text: _site?.address ?? '');
  late final TextEditingController _cuisine = TextEditingController(text: _site?.cuisine ?? '');
  late final TextEditingController _imageUrl = TextEditingController(text: _site?.imageUrl ?? '');
  late final TextEditingController _statusLabel = TextEditingController(text: _site?.statusLabel ?? 'Abierto');
  late RestaurantCategory _category = _categoryLabels.containsKey(_site?.category) ? _site!.category : 'bistro';
  late RestaurantOperationalStatus _status = _statusLabels.containsKey(_site?.status) ? _site!.status : 'active';
  late String _currency = _site?.currency ?? 'EUR';
  late String _timezone = _site?.timezone ?? 'Europe/Madrid';

  /// Solo al crear: cuántos pisos tiene el local (se nombran Piso 1, Piso 2…).
  int _floorsCount = 1;
  String? _formError;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_code, _name, _city, _address, _cuisine, _imageUrl, _statusLabel]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _city.text.trim().isEmpty) {
      setState(() => _formError = 'Indica al menos el nombre y la ciudad de la sede.');
      return;
    }

    final code = _code.text.trim();
    final imageUrl = _imageUrl.text.trim();
    final draft = NewRestaurantDraft(
      code: code.isNotEmpty ? code : 'SEDE-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : _defaultImageUrl,
      currency: _currency,
      timezone: _timezone,
      name: _name.text.trim(),
      city: _city.text.trim(),
      address: _address.text.trim(),
      cuisine: _cuisine.text.trim(),
      status: _status,
      statusLabel: _statusLabel.text.trim(),
      category: _category,
      categoryLabel: _categoryLabels[_category]!,
      floorsCount: _site == null ? _floorsCount : null,
    );

    final onSave = widget.onSave;

    if (onSave == null) {
      Navigator.of(context).pop(draft);
      return;
    }

    setState(() {
      _formError = null;
      _saving = true;
    });

    final error = await onSave(draft);

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(draft);
    } else {
      setState(() {
        _saving = false;
        _formError = error;
      });
    }
  }

  Widget _dropdown(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [for (final entry in options.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isEdit = _site != null;
    const gap = SizedBox(height: 16);
    final floorNames = List.generate(_floorsCount < 3 ? _floorsCount : 3, (index) => 'Piso ${index + 1}').join(', ');

    return BaseDialogFrame(
      title: isEdit ? 'Editar sede' : 'Nueva sede',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).maybePop()),
          const Spacer(),
          BaseButton(label: isEdit ? 'Guardar' : 'Crear sede', variant: 'primary', loading: _saving, onPressed: _submit),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isEdit) ...[
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Código', hintText: 'LIM-01-MIR')),
            gap,
          ],
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
          gap,
          Row(
            children: [
              Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad'))),
              const SizedBox(width: 12),
              Expanded(child: _dropdown('Categoría', _category, _categoryLabels, (value) => setState(() => _category = value))),
            ],
          ),
          if (!isEdit) ...[
            gap,
            Text('PISOS DEL LOCAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurfaceVariant, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Quitar un piso',
                        onPressed: _floorsCount <= 1 ? null : () => setState(() => _floorsCount--),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      SizedBox(
                        width: 32,
                        child: Semantics(
                          liveRegion: true,
                          child: Text('$_floorsCount', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.onSurface)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Agregar un piso',
                        onPressed: _floorsCount >= _maxFloors ? null : () => setState(() => _floorsCount++),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$floorNames${_floorsCount > 3 ? '…' : ''}. Podrás renombrarlos en Gestión de mesas.',
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          gap,
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Dirección')),
          gap,
          TextField(controller: _cuisine, decoration: const InputDecoration(labelText: 'Cocina')),
          gap,
          TextField(
            controller: _imageUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Imagen (URL)', hintText: 'https://…'),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: _dropdown('Moneda', _currency, {for (final option in CURRENCY_OPTIONS) option: option},
                    (value) => setState(() => _currency = value)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown('Zona horaria', _timezone, {for (final option in TIMEZONE_OPTIONS) option: option},
                    (value) => setState(() => _timezone = value)),
              ),
            ],
          ),
          gap,
          Row(
            children: [
              Expanded(child: _dropdown('Estado operativo', _status, _statusLabels, (value) => setState(() => _status = value))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _statusLabel, decoration: const InputDecoration(labelText: 'Descripción del estado'))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Una sede inactiva o suspendida no aparece para los comensales y no puede abrir pedidos nuevos.',
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(8)),
              child: Text(_formError!, style: TextStyle(fontSize: 13, color: c.onErrorContainer)),
            ),
          ],
        ],
      ),
    );
  }
}
