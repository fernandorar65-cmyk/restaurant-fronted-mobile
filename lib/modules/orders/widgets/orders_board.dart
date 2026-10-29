import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../stores/session_store.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../rounds.dart';
import '../types.dart';
import 'service_ui.dart';

/// Comanda del tablero: los productos de una misma ronda de una mesa que están en un estado.
class BoardCard {
  const BoardCard({
    required this.key,
    required this.attention,
    required this.roundNumber,
    required this.requestedAt,
    required this.createdBy,
    required this.status,
    required this.products,
  });

  final String key;
  final AttentionWithProducts attention;
  final int roundNumber;
  final String requestedAt;
  final String? createdBy;
  final OrderedProductStatus status;
  final List<OrderedProduct> products;

  int get units => products.fold<int>(0, (sum, product) => sum + product.quantity);
}

/// Pedido de avance de una comanda al siguiente estado.
class AdvancePayload {
  const AdvancePayload({required this.key, required this.tableNumber, required this.products, required this.to});

  final String key;
  final String tableNumber;
  final List<OrderedProduct> products;
  final OrderedProductStatus to;
}

class _Column {
  const _Column(this.status, this.title, this.hint);

  final OrderedProductStatus status;
  final String title;
  final String hint;
}

const List<_Column> _columns = [
  _Column('sent', 'Nuevos', 'Por confirmar'),
  _Column('preparing', 'En preparación', 'En cocina'),
  _Column('ready', 'Listos', 'Para servir'),
  _Column('delivered', 'Entregados', 'Mesas en curso'),
];

Color _columnColor(BuildContext context, OrderedProductStatus status) => switch (status) {
  'sent' => context.colors.error,
  'preparing' => context.colors.primary,
  'ready' => context.colors.tertiary,
  _ => context.colors.success,
};

/// Arma las comandas del tablero (solo mesas en curso).
List<BoardCard> buildBoardCards(List<AttentionWithProducts> attentions) => [
  for (final attention in attentions)
    if (isAttentionActive(attention))
      for (final (index, round) in groupByRound(attention.products).indexed)
        for (final column in _columns)
          if (round.products.any((product) => product.status == column.status))
            BoardCard(
              key: '${round.batchId}:${column.status}',
              attention: attention,
              roundNumber: index + 1,
              requestedAt: round.requestedAt,
              createdBy: round.createdBy,
              status: column.status,
              products: round.products.where((product) => product.status == column.status).toList(),
            ),
];

/// Demora de una comanda según su columna.
DelayLevel boardCardDelay(BoardCard card, int now) {
  if (card.status == 'delivered') return 'ok';
  final limit = card.status == 'preparing' ? kitchenDelayMinutes : incomingDelayMinutes;
  return delayLevel(minutesSince(card.requestedAt, now), limit);
}

/// Tablero de pedidos por estado. En móvil, una columna a la vista: se elige con chips
/// (con su conteo) y cada tarjeta se avanza con su botón.
class OrdersBoard extends StatefulWidget {
  const OrdersBoard({
    super.key,
    required this.attentions,
    required this.now,
    required this.busyKey,
    required this.onAdvance,
    required this.onSelect,
  });

  final List<AttentionWithProducts> attentions;
  final int now;

  /// Tarjeta que se está actualizando.
  final String? busyKey;
  final ValueChanged<AdvancePayload> onAdvance;

  /// Al tocar una tarjeta: abre el detalle de la comanda.
  final ValueChanged<BoardCard> onSelect;

  @override
  State<OrdersBoard> createState() => _OrdersBoardState();
}

class _OrdersBoardState extends State<OrdersBoard> {
  OrderedProductStatus _selected = 'sent';

  bool _canAdvance(SessionStore session, BoardCard card) {
    final permission = orderedProductStepPermission[card.status];
    return nextOrderedProductStatus(card.status) != null && permission != null && session.can(permission);
  }

  void _advance(SessionStore session, BoardCard card) {
    final to = nextOrderedProductStatus(card.status);

    if (to != null && _canAdvance(session, card)) {
      widget.onAdvance(AdvancePayload(key: card.key, tableNumber: card.attention.tableNumber, products: card.products, to: to));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final cards = buildBoardCards(widget.attentions);
    final byColumn = {
      for (final column in _columns)
        column.status: cards.where((card) => card.status == column.status).toList()
          // Activas: la más antigua primero (atender en orden). Entregados: la más reciente primero.
          ..sort((a, b) => column.status == 'delivered' ? b.requestedAt.compareTo(a.requestedAt) : a.requestedAt.compareTo(b.requestedAt)),
    };
    final column = _columns.firstWhere((item) => item.status == _selected);
    final items = byColumn[_selected]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in _columns)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _selected == item.status,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _columnColor(context, item.status), shape: BoxShape.circle),
                    ),
                    label: Text('${item.title} · ${byColumn[item.status]!.length}', style: tabular(AppFonts.label(fontSize: 14))),
                    tooltip: '${item.title}: ${byColumn[item.status]!.length} comandas',
                    onSelected: (_) => setState(() => _selected = item.status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(column.hint, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.7)),
            ),
            alignment: Alignment.center,
            child: Text('Sin comandas', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
          )
        else
          for (final card in items) ...[
            _BoardCardTile(
              card: card,
              color: _columnColor(context, card.status),
              delay: boardCardDelay(card, widget.now),
              now: widget.now,
              busy: widget.busyKey == card.key,
              canAdvance: _canAdvance(session, card),
              onTap: () => widget.onSelect(card),
              onAdvance: () => _advance(session, card),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _BoardCardTile extends StatelessWidget {
  const _BoardCardTile({
    required this.card,
    required this.color,
    required this.delay,
    required this.now,
    required this.busy,
    required this.canAdvance,
    required this.onTap,
    required this.onAdvance,
  });

  final BoardCard card;
  final Color color;
  final DelayLevel delay;
  final int now;
  final bool busy;
  final bool canAdvance;
  final VoidCallback onTap;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color delayBg, Color delayFg) = switch (delay) {
      'critical' => (c.errorContainer, c.onErrorContainer),
      'warning' => (c.warningContainer, c.onWarningContainer),
      _ => (c.surfaceContainer, c.onSurfaceVariant),
    };
    final units = card.units;
    final label = delayLabel[delay] ?? '';
    final next = nextOrderedProductStatus(card.status);

    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Semantics(
        button: true,
        label:
            'Ver detalle: mesa ${card.attention.tableNumber}, ronda ${card.roundNumber}${label.isNotEmpty ? ', ${label.toLowerCase()}' : ''}',
        child: Material(
          color: c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          elevation: 0.5,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Franja del color de la columna (estado); la demora la indica la etiqueta del tiempo.
                  Container(width: 4, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mesa ${card.attention.tableNumber}',
                                      style: AppFonts.headline(fontSize: 18, color: c.onSurface, height: 1.2),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          card.createdBy != null ? Icons.person_outline_rounded : Icons.qr_code_2_rounded,
                                          size: 14,
                                          color: c.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Ronda ${card.roundNumber} · ${card.createdBy ?? 'QR'}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Tooltip(
                                message: label,
                                child: Pill(
                                  formatElapsed(card.requestedAt, now).replaceAll('hace ', ''),
                                  icon: Icons.schedule_rounded,
                                  background: delayBg,
                                  foreground: delayFg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final product in card.products)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 24),
                                    height: 20,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      '${product.quantity}',
                                      style: tabular(AppFonts.label(fontSize: 12, fontWeight: FontWeight.w700, color: c.onPrimaryFixed)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product.name, style: TextStyle(fontSize: 14, color: c.onSurface)),
                                        if (product.notes.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: c.tertiaryFixed.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_outlined, size: 12, color: c.onTertiaryContainer),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    product.notes,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: c.onTertiaryContainer,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Divider(height: 12, color: c.outlineVariant.withValues(alpha: 0.4)),
                          Row(
                            children: [
                              Text('$units ${units == 1 ? 'plato' : 'platos'}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                              const Spacer(),
                              if (canAdvance && next != null)
                                Semantics(
                                  label:
                                      '${nextOrderedProductActionLabel(card.status)}: mesa ${card.attention.tableNumber}, pasa a ${orderedProductStatusLabel[next]}',
                                  excludeSemantics: true,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      backgroundColor: c.primary,
                                      foregroundColor: c.onPrimary,
                                      shape: const StadiumBorder(),
                                      textStyle: AppFonts.label(fontSize: 13),
                                    ),
                                    onPressed: busy ? null : onAdvance,
                                    iconAlignment: IconAlignment.end,
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                    label: Text(busy ? 'Moviendo…' : nextOrderedProductActionLabel(card.status)!),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
