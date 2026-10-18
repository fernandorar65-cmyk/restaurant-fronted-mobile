import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../stores/session_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../menus/api.dart';
import '../../menus/types.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../types.dart';
import 'orders_board.dart';
import 'service_ui.dart';

/// Resultado del detalle de comanda: el usuario pidió ver la mesa completa.
const String openAttentionResult = 'open-attention';

/// Abre el detalle de una comanda del tablero. Devuelve [openAttentionResult] si se pidió
/// "Ver mesa completa". [onAdvance] mueve la comanda al siguiente estado (la hoja se cierra al terminar).
Future<String?> showOrderTicketDialog(
  BuildContext context, {
  required BoardCard ticket,
  required String currency,
  String? timezone,
  required int now,
  required Future<void> Function() onAdvance,
}) {
  return showServiceSheet<String>(
    context,
    builder: (_) => OrderTicketDialog(ticket: ticket, currency: currency, timezone: timezone, now: now, onAdvance: onAdvance),
  );
}

/// Detalle de una comanda del tablero: platos con su ficha, línea de tiempo y acciones.
class OrderTicketDialog extends StatefulWidget {
  const OrderTicketDialog({
    super.key,
    required this.ticket,
    required this.currency,
    this.timezone,
    required this.now,
    required this.onAdvance,
  });

  final BoardCard ticket;
  final String currency;
  final String? timezone;
  final int now;
  final Future<void> Function() onAdvance;

  @override
  State<OrderTicketDialog> createState() => _OrderTicketDialogState();
}

class _Step {
  const _Step(this.status, this.label, {this.at, this.by, required this.done, required this.current});

  final OrderedProductStatus status;
  final String label;
  final String? at;
  final String? by;
  final bool done;
  final bool current;
}

const List<(OrderedProductStatus, String)> _steps = [
  ('sent', 'Pedido'),
  ('preparing', 'En preparación'),
  ('ready', 'Listo'),
  ('delivered', 'Entregado'),
];

class _OrderTicketDialogState extends State<OrderTicketDialog> {
  List<MenuProduct> _menu = const [];
  List<StatusHistoryEntry> _history = const [];
  bool _isLoading = true;
  bool _busy = false;

  BoardCard get _ticket => widget.ticket;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        fetchMenuProducts(_ticket.attention.restaurantId),
        fetchAttentionTimeline(_ticket.attention.id, _ticket.products.map((product) => product.id).toList()),
      ]);
      if (!mounted) return;
      setState(() {
        _menu = results[0] as List<MenuProduct>;
        _history = results[1] as List<StatusHistoryEntry>;
      });
    } catch (_) {
      // Sin ficha ni historial se puede seguir operando la comanda.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  MenuProduct? _infoFor(OrderedProduct product) {
    for (final item in _menu) {
      if (item.id == product.productId) return item;
    }
    return null;
  }

  /// Para cada paso, el primer momento en que algún plato llegó a ese estado y quién lo hizo.
  List<_Step> get _timeline {
    final ids = _ticket.products.map((product) => product.id).toSet();
    final currentIndex = _steps.indexWhere((step) => step.$1 == _ticket.status);

    return [
      for (final (index, (status, label)) in _steps.indexed)
        if (status == 'sent')
          _Step(status, label, at: _ticket.requestedAt, by: _ticket.createdBy ?? 'Cliente (QR)', done: true, current: index == currentIndex)
        else
          () {
            // Se ignoran registros anteriores al pedido (datos viejos o inconsistentes).
            final entries =
                _history
                    .where(
                      (item) =>
                          item.entityType == 'orderedProduct' &&
                          ids.contains(item.entityId) &&
                          item.toStatus == status &&
                          item.changedAt.compareTo(_ticket.requestedAt) >= 0,
                    )
                    .toList()
                  ..sort((a, b) => a.changedAt.compareTo(b.changedAt));
            final entry = entries.isEmpty ? null : entries.first;
            return _Step(
              status,
              label,
              at: entry?.changedAt,
              by: entry?.userName,
              done: index <= currentIndex,
              current: index == currentIndex,
            );
          }(),
    ];
  }

  int _minutesBetween(String from, String to) => max(0, (parseIso(to).difference(parseIso(from)).inSeconds / 60).round());

  Future<void> _advance() async {
    setState(() => _busy = true);
    await widget.onAdvance();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final lines = [for (final product in _ticket.products) (product, _infoFor(product))];
    final total = _ticket.products.fold<double>(0, (sum, product) => sum + product.subtotal);
    final units = _ticket.units;
    final allergens = {for (final line in lines) ...?line.$2?.allergens}.toList();
    final estimatedMinutes = lines.fold<int>(0, (acc, line) => max(acc, line.$2?.prepMinutes ?? 0));
    final next = nextOrderedProductStatus(_ticket.status);
    final permission = orderedProductStepPermission[_ticket.status];
    final canAdvance = next != null && permission != null && session.can(permission);
    final timeline = _timeline;

    Widget summaryTile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: tabular(AppFonts.headline(fontSize: 19, color: c.onSurface))),
            ),
          ],
        ),
      ),
    );

    return BaseDialogFrame(
      title: 'Mesa ${_ticket.attention.tableNumber} · Ronda ${_ticket.roundNumber}',
      eyebrow: orderedProductStatusLabel[_ticket.status],
      subtitle:
          'Pedido ${formatElapsed(_ticket.requestedAt, widget.now)} · ${_ticket.createdBy != null ? 'cargado por ${_ticket.createdBy}' : 'por QR'}',
      footer: Row(
        children: [
          BaseButton(label: 'Ver mesa completa', variant: 'ghost', onPressed: () => Navigator.of(context).pop(openAttentionResult)),
          const Spacer(),
          if (canAdvance)
            Flexible(
              flex: 3,
              child: BaseButton(
                label: '${nextOrderedProductActionLabel(_ticket.status)} → ${orderedProductStatusLabel[next]}',
                variant: 'primary',
                loading: _busy,
                onPressed: _advance,
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              summaryTile('Platos', '$units'),
              const SizedBox(width: 8),
              summaryTile('Importe', formatMoney(total, widget.currency)),
              const SizedBox(width: 8),
              summaryTile('Prep. estimada', estimatedMinutes > 0 ? '$estimatedMinutes min' : '—'),
            ],
          ),
          if (allergens.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: c.onWarningContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 14, color: c.onWarningContainer),
                        children: [
                          const TextSpan(text: 'Contiene '),
                          TextSpan(
                            text: allergens.join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: '. Confirma alergias con la mesa.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('PLATOS', style: AppFonts.eyebrow(color: c.outline)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                for (final (index, (product, info)) in lines.indexed) ...[
                  if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: info != null && info.imageUrl.isNotEmpty
                                ? Image.network(
                                    info.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceContainer),
                                  )
                                : ColoredBox(color: c.surfaceContainer),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                                        children: [
                                          TextSpan(
                                            text: '${product.quantity}× ',
                                            style: TextStyle(color: c.primary),
                                          ),
                                          TextSpan(text: product.name),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatMoney(product.subtotal, widget.currency),
                                    style: tabular(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                                  ),
                                ],
                              ),
                              if (product.notes.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.tertiaryFixed.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Nota: ${product.notes}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onTertiaryContainer),
                                  ),
                                ),
                              if (info != null && info.ingredients.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(info.ingredients.join(' · '), style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                                ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    '${formatMoney(product.unitPrice, widget.currency)} c/u',
                                    style: tabular(TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                                  ),
                                  if ((info?.prepMinutes ?? 0) > 0)
                                    Text(
                                      '${info!.prepMinutes} min de preparación',
                                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                    ),
                                  if (info != null && info.portion.isNotEmpty)
                                    Text(info.portion, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 6),
            Text('Cargando ficha de los platos…', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          Text('SEGUIMIENTO', style: AppFonts.eyebrow(color: c.outline)),
          const SizedBox(height: 8),
          for (final (index, step) in timeline.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: step.current ? c.primary : (step.done ? c.primaryFixed : c.surfaceContainer),
                          ),
                          alignment: Alignment.center,
                          child: step.done && !step.current
                              ? Icon(Icons.check_rounded, size: 14, color: c.onPrimaryFixed)
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: step.current ? c.onPrimary : c.outline),
                                ),
                        ),
                        if (index < timeline.length - 1)
                          Expanded(child: Container(width: 2, color: timeline[index + 1].done ? c.primary : c.outlineVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: index < timeline.length - 1 ? 16 : 0, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  step.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: step.done ? FontWeight.w600 : FontWeight.w400,
                                    color: step.done ? c.onSurface : c.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                step.at != null ? formatTime(step.at!, widget.timezone) : 'Pendiente',
                                style: tabular(TextStyle(fontSize: 12, color: step.at != null ? c.onSurfaceVariant : c.outline)),
                              ),
                            ],
                          ),
                          if (_stepDetail(timeline, index) case final detail?)
                            Text(detail, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                        ],
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

  String? _stepDetail(List<_Step> timeline, int index) {
    final step = timeline[index];
    final previousAt = index > 0 ? timeline[index - 1].at : null;
    final parts = <String>[
      if (step.by != null) step.by!,
      if (step.at != null && previousAt != null) '${_minutesBetween(previousAt, step.at!)} min desde el paso anterior',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
