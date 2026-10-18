import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/string.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../types.dart';

class _DraftFloor {
  _DraftFloor(this.id, String name) : controller = TextEditingController(text: name);

  final String id;
  final TextEditingController controller;
}

/// Pisos de una sede: crear, renombrar y eliminar. Al eliminar un piso con mesas,
/// se elige a qué piso pasan; siempre queda al menos uno.
///
/// [onSave] guarda y devuelve un mensaje de error (la hoja sigue abierta) o null (se cierra).
class FloorsDialog extends StatefulWidget {
  const FloorsDialog({super.key, required this.floors, required this.tables, required this.onSave});

  final List<SiteFloor> floors;
  final List<LiveTable> tables;
  final Future<String?> Function(List<SiteFloor> floors, List<LiveTable> tables) onSave;

  static Future<void> show(
    BuildContext context, {
    required List<SiteFloor> floors,
    required List<LiveTable> tables,
    required Future<String?> Function(List<SiteFloor> floors, List<LiveTable> tables) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FloorsDialog(floors: floors, tables: tables, onSave: onSave),
    );
  }

  @override
  State<FloorsDialog> createState() => _FloorsDialogState();
}

class _FloorsDialogState extends State<FloorsDialog> {
  late final List<_DraftFloor> _draft = [for (final floor in widget.floors) _DraftFloor(floor.id, floor.name)];
  final List<_DraftFloor> _removed = [];

  /// Piso eliminado → piso que recibe sus mesas.
  final Map<String, String> _moves = {};
  final TextEditingController _newName = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final floor in [..._draft, ..._removed]) {
      floor.controller.dispose();
    }
    _newName.dispose();
    super.dispose();
  }

  int _tableCount(String floorId) => widget.tables.where((table) => table.floorId == floorId).length;

  String _uniqueId(String name) {
    final slug = slugify(name);
    final base = slug.isNotEmpty ? slug : 'piso';
    var id = base;

    for (var index = 2;
        _draft.any((floor) => floor.id == id) || widget.floors.any((floor) => floor.id == id);
        index++) {
      id = '$base-$index';
    }

    return id;
  }

  void _addFloor() {
    final name = _newName.text.trim();
    setState(() => _error = null);

    if (name.isEmpty) return;

    if (_draft.any((floor) => floor.controller.text.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = 'Ya existe un piso llamado "$name".');
      return;
    }

    setState(() {
      _draft.add(_DraftFloor(_uniqueId(name), name));
      _newName.clear();
    });
  }

  void _removeFloor(_DraftFloor floor) {
    if (_draft.length <= 1) return;

    setState(() {
      _draft.remove(floor);
      _removed.add(floor);
      final first = _draft.first.id;

      if (_tableCount(floor.id) > 0) _moves[floor.id] = first;

      // Si otro piso eliminado mandaba sus mesas a este, se redirigen.
      for (final entry in _moves.entries.toList()) {
        if (entry.value == floor.id) _moves[entry.key] = first;
      }
    });
  }

  List<SiteFloor> get _removedWithTables => widget.floors
      .where((floor) => !_draft.any((item) => item.id == floor.id) && _tableCount(floor.id) > 0)
      .toList();

  Future<void> _save() async {
    setState(() => _error = null);

    if (_draft.any((floor) => floor.controller.text.trim().isEmpty)) {
      setState(() => _error = 'Todos los pisos necesitan un nombre.');
      return;
    }

    final names = _draft.map((floor) => floor.controller.text.trim().toLowerCase()).toList();

    if (names.toSet().length != names.length) {
      setState(() => _error = 'Hay dos pisos con el mismo nombre.');
      return;
    }

    setState(() => _saving = true);

    final error = await widget.onSave(
      [for (final floor in _draft) SiteFloor(id: floor.id, name: floor.controller.text.trim())],
      [
        for (final table in widget.tables)
          _moves[table.floorId] != null ? table.copyWith(floorId: _moves[table.floorId]) : table,
      ],
    );

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
    final canRemove = _draft.length > 1;

    return BaseDialogFrame(
      title: 'Pisos de la sede',
      subtitle: 'Organiza las mesas por planta, terraza o salón.',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).maybePop()),
          const Spacer(),
          BaseButton(label: 'Guardar pisos', variant: 'primary', loading: _saving, onPressed: _save),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final floor in _draft)
            Padding(
              key: ValueKey(floor.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: floor.controller,
                      decoration: const InputDecoration(isDense: true, hintText: 'Nombre del piso'),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${_tableCount(floor.id)} ${_tableCount(floor.id) == 1 ? 'mesa' : 'mesas'}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    tooltip: canRemove ? 'Eliminar piso' : 'La sede necesita al menos un piso',
                    onPressed: canRemove ? () => _removeFloor(floor) : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                    style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newName,
                  decoration: const InputDecoration(isDense: true, hintText: 'Ej: Primer piso, Terraza'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addFloor(),
                ),
              ),
              const SizedBox(width: 8),
              BaseButton(label: 'Agregar', onPressed: _addFloor),
            ],
          ),
          if (_removedWithTables.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final floor in _removedWithTables)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'Las ${_tableCount(floor.id)} mesas de '),
                              TextSpan(text: floor.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const TextSpan(text: ' pasan a'),
                            ]),
                            style: TextStyle(fontSize: 14, color: c.onWarningContainer),
                          ),
                          DropdownButton<String>(
                            value: _draft.any((target) => target.id == _moves[floor.id]) ? _moves[floor.id] : null,
                            isDense: true,
                            items: [
                              for (final target in _draft) DropdownMenuItem(value: target.id, child: Text(target.controller.text)),
                            ],
                            onChanged: (value) => setState(() {
                              if (value != null) _moves[floor.id] = value;
                            }),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
