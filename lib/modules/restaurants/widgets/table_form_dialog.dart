import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../site_labels.dart';
import '../types.dart';

final Random _random = Random.secure();

/// Token de QR de 16 caracteres hexadecimales (equivale a `crypto.randomUUID()` sin guiones, recortado).
String createQrToken() {
  const hex = '0123456789abcdef';
  return List.generate(16, (_) => hex[_random.nextInt(16)]).join();
}

/// Alta o edición de una mesa. [onSave] guarda y devuelve un mensaje de error
/// (la hoja sigue abierta) o null (la hoja se cierra).
class TableFormDialog extends StatefulWidget {
  const TableFormDialog({
    super.key,
    this.table,
    required this.existingNumbers,
    required this.floors,
    this.defaultFloorId,
    required this.onSave,
  });

  /// Mesa a editar; sin ella el diálogo crea una mesa nueva.
  final LiveTable? table;
  final List<String> existingNumbers;
  final List<SiteFloor> floors;

  /// Piso preseleccionado para una mesa nueva (el que se está viendo).
  final String? defaultFloorId;
  final Future<String?> Function(LiveTable table) onSave;

  static Future<void> show(
    BuildContext context, {
    LiveTable? table,
    required List<String> existingNumbers,
    required List<SiteFloor> floors,
    String? defaultFloorId,
    required Future<String?> Function(LiveTable table) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TableFormDialog(
        table: table,
        existingNumbers: existingNumbers,
        floors: floors,
        defaultFloorId: defaultFloorId,
        onSave: onSave,
      ),
    );
  }

  @override
  State<TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<TableFormDialog> {
  late final TextEditingController _number = TextEditingController(text: widget.table?.number ?? '');
  late final TextEditingController _code = TextEditingController(text: widget.table?.code ?? '');
  late final TextEditingController _seats = TextEditingController(text: '${widget.table?.seats ?? 2}');
  late final TextEditingController _location = TextEditingController(text: widget.table?.location ?? 'Sala principal');
  late TableStatus _status = widget.table?.status ?? 'active';
  late String _floorId = widget.table?.floorId ?? widget.defaultFloorId ?? (widget.floors.isNotEmpty ? widget.floors.first.id : '');
  String? _formError;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _code.dispose();
    _seats.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trimmed = _number.text.trim();
    final seats = int.tryParse(_seats.text.trim()) ?? 0;

    if (trimmed.isEmpty) {
      setState(() => _formError = 'Indica el número de la mesa.');
      return;
    }

    if (trimmed != widget.table?.number && widget.existingNumbers.contains(trimmed)) {
      setState(() => _formError = 'Ya existe la mesa $trimmed.');
      return;
    }

    if (seats < 1) {
      setState(() => _formError = 'La mesa debe tener al menos una silla.');
      return;
    }

    final base = widget.table ??
        LiveTable(
          number: trimmed,
          floorId: _floorId,
          code: '',
          status: 'active',
          seats: seats,
          occupiedSeats: 0,
          floorStatus: 'available',
          guests: 0,
          tagLabel: 'Nueva',
          tagTone: 'neutral',
          location: '',
          staff: 'Sin asignar',
          statusLabel: 'Libre',
          courseLabel: '—',
          dish: 'Mesa lista',
          note: '',
          qrToken: createQrToken(),
          qrActive: true,
        );
    final code = _code.text.trim();
    final location = _location.text.trim();

    setState(() {
      _formError = null;
      _saving = true;
    });

    final error = await widget.onSave(base.copyWith(
      number: trimmed,
      floorId: _floorId,
      code: code.isNotEmpty ? code : 'M-$trimmed',
      status: _status,
      seats: seats,
      occupiedSeats: min(base.occupiedSeats, seats),
      location: location.isNotEmpty ? location : 'Sala principal',
      note: '$seats sillas',
    ));

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _formError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isEdit = widget.table != null;

    return BaseDialogFrame(
      title: isEdit ? 'Editar mesa ${widget.table!.number}' : 'Nueva mesa',
      footer: Row(
        children: [
          BaseButton(label: 'Cancelar', variant: 'ghost', onPressed: () => Navigator.of(context).maybePop()),
          const Spacer(),
          BaseButton(label: isEdit ? 'Guardar' : 'Crear mesa', variant: 'primary', loading: _saving, onPressed: _submit),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Número', hintText: '13'),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Código', hintText: 'M-13'),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seats,
                  decoration: const InputDecoration(labelText: 'Sillas'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          if (widget.floors.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: widget.floors.any((floor) => floor.id == _floorId) ? _floorId : null,
              decoration: const InputDecoration(labelText: 'Piso'),
              items: [for (final floor in widget.floors) DropdownMenuItem(value: floor.id, child: Text(floor.name))],
              onChanged: (value) => setState(() => _floorId = value ?? _floorId),
            ),
          ],
          const SizedBox(height: 16),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Zona / nombre')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Estado',
              helperText: 'Una mesa en mantenimiento o inactiva no puede abrir pedidos.',
              helperMaxLines: 2,
            ),
            items: [
              for (final option in const ['active', 'maintenance', 'inactive'])
                DropdownMenuItem(value: option, child: Text(tableStatusLabel[option] ?? option)),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
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
