import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/base_dialog.dart';
import '../../../widgets/base/status_badge.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../rounds.dart';
import '../types.dart';
import 'service_ui.dart';

/// Resultado de la hoja: se pidió agregar productos a la mesa.
const String addProductsResult = 'add-products';

/// Abre el detalle de una atención. [source] es la lista viva de atenciones de la vista: la hoja
/// se actualiza cuando la vista recarga. Devuelve [addProductsResult] si se pidió "+ Agregar productos".
Future<String?> showAttentionDialog(
  BuildContext context, {
  required AttentionWithProducts attention,
  required ValueListenable<List<AttentionWithProducts>> source,
  required String currency,
  String? timezone,
  required Future<void> Function() onChanged,
}) {
  return showServiceSheet<String>(
    context,
    builder: (_) => ValueListenableBuilder<List<AttentionWithProducts>>(
      valueListenable: source,
      builder: (context, list, _) {
        final current = list.where((item) => item.id == attention.id).firstOrNull ?? attention;
        return AttentionDialog(attention: current, currency: currency, timezone: timezone, onChanged: onChanged);
      },
    ),
  );
}

/// Detalle de la atención de una mesa: rondas, avance/rechazo/cancelación de productos,
/// historial de estados y cancelación de la atención.
class AttentionDialog extends StatefulWidget {
  const AttentionDialog({super.key, required this.attention, required this.currency, this.timezone, required this.onChanged});

  final AttentionWithProducts attention;
  final String currency;
  final String? timezone;
  final Future<void> Function() onChanged;

  @override
  State<AttentionDialog> createState() => _AttentionDialogState();
}

class _AttentionDialogState extends State<AttentionDialog> {
  ({String productId, String action})? _reasonFor;
  final _reason = TextEditingController();
  bool _isCancellingAttention = false;
  final _cancelReason = TextEditingController();
  bool _isHistoryOpen = false;
  List<StatusHistoryEntry> _history = const [];
  String? _busyId;
  String? _actionError;

  AttentionWithProducts get _attention => widget.attention;

  @override
  void dispose() {
    _reason.dispose();
    _cancelReason.dispose();
    super.dispose();
  }

  String get _staffName => context.read<SessionStore>().user?.name ?? 'Personal';

  bool get _isActive => isAttentionActive(_attention);

  bool _canAdvance(SessionStore session, OrderedProduct product) {
    final permission = orderedProductStepPermission[product.status];
    return _isActive && permission != null && session.can(permission);
  }

  Future<void> _run(OrderedProduct product, OrderedProductStatus toStatus, [String? why]) async {
    setState(() {
      _busyId = product.id;
      _actionError = null;
    });

    try {
      await updateOrderedProductStatus(product, toStatus, _staffName, why);
      if (!mounted) return;
      setState(() => _reasonFor = null);
      _reason.clear();
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = errorMessage(error, 'No se pudo actualizar el producto.'));

      if (error is ConflictError) {
        await widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _advance(OrderedProduct product) async {
    final next = nextOrderedProductStatus(product.status);

    if (next != null) {
      await _run(product, next);
    }
  }

  void _askReason(OrderedProduct product, String action) {
    _reason.clear();
    setState(() => _reasonFor = (productId: product.id, action: action));
  }

  Future<void> _confirmReason(OrderedProduct product) async {
    final reasonFor = _reasonFor;

    if (reasonFor == null || _reason.text.trim().isEmpty) {
      return;
    }

    await _run(product, reasonFor.action, _reason.text.trim());
  }

  Future<void> _confirmCancelAttention() async {
    if (_cancelReason.text.trim().isEmpty) {
      return;
    }

    setState(() => _actionError = null);
    final toast = context.read<ToastStore>();
    final navigator = Navigator.of(context);

    try {
      await cancelAttention(_attention, _staffName, _cancelReason.text);
      toast.show('Atención de la mesa ${_attention.tableNumber} cancelada', tone: 'info');
      await widget.onChanged();
      navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo cancelar la atención.'));
    }
  }

  Future<void> _toggleHistory() async {
    setState(() => _isHistoryOpen = !_isHistoryOpen);

    if (_isHistoryOpen) {
      try {
        final history = await fetchAttentionTimeline(_attention.id, _attention.products.map((product) => product.id).toList());
        if (mounted) setState(() => _history = history);
      } catch (error) {
        if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo cargar el historial.'));
      }
    }
  }

  String _productName(StatusHistoryEntry entry) {
    if (entry.entityType == 'attention') {
      return 'Atención';
    }

    return _attention.products.where((product) => product.id == entry.entityId).firstOrNull?.name ?? 'Producto';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final rounds = groupByRound(_attention.products);
    final total = _attention.products.where((product) => isBillableProduct(product.status)).fold<double>(0, (sum, p) => sum + p.subtotal);
    final canManage = session.can('orders.manage');

    return BaseDialogFrame(
      eyebrow: 'Atención de mesa',
      title: 'Mesa ${_attention.tableNumber}',
      subtitle: 'Abierta a las ${formatTime(_attention.openedAt, widget.timezone)}',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (_isActive && canManage && !_isCancellingAttention)
            Material(
              color: c.surfaceContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => setState(() => _isCancellingAttention = true),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      widthFactor: 1,
                      child: Text('Cancelar atención', style: AppFonts.label(fontSize: 14, color: c.error)),
                    ),
                  ),
                ),
              ),
            ),
          if (_isActive && canManage)
            BaseButton(label: '+ Agregar productos', variant: 'primary', onPressed: () => Navigator.of(context).pop(addProductsResult)),
          BaseButton(label: 'Cerrar', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                tone: attentionStatusTone[_attention.status] ?? 'neutral',
                label: attentionStatusLabel[_attention.status] ?? _attention.status,
              ),
              if (_attention.status == 'account-requested')
                Text('El comensal solicitó la cuenta', style: AppFonts.label(fontSize: 12, color: c.tertiary)),
              if ((_attention.cancellationReason ?? '').isNotEmpty)
                Text('Motivo: ${_attention.cancellationReason}', style: TextStyle(fontSize: 12, color: c.error)),
            ],
          ),
          if (_actionError != null) ...[const SizedBox(height: 12), InlineAlert(_actionError!)],
          for (final (index, round) in rounds.indexed) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'RONDA ${index + 1} · ${formatTime(round.requestedAt, widget.timezone)}',
                  style: AppFonts.eyebrow(color: c.onSurfaceVariant),
                ),
                Pill(
                  round.createdBy != null ? 'Cargado por ${round.createdBy}' : 'Pedido por QR',
                  background: c.surfaceContainer,
                  foreground: c.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final product in round.products) ...[_productTile(context, session, product), const SizedBox(height: 8)],
          ],
          if (rounds.isEmpty) ...[
            const SizedBox(height: 16),
            Text('Todavía no hay productos en esta atención.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Total cobrable', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                ),
                Text(formatMoney(total, widget.currency), style: tabular(AppFonts.headline(fontSize: 18, color: c.onSurface))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: EdgeInsets.zero),
              onPressed: _toggleHistory,
              child: Text(
                _isHistoryOpen ? 'Ocultar historial' : 'Ver historial de estados',
                style: AppFonts.label(fontSize: 13, color: c.primaryInk),
              ),
            ),
          ),
          if (_isHistoryOpen)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_history.isEmpty) Text('Sin cambios registrados.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  for (final entry in _history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          children: [
                            TextSpan(
                              text: formatTime(entry.changedAt, widget.timezone),
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                            ),
                            TextSpan(text: ' · ${_productName(entry)} → '),
                            TextSpan(
                              text: historyStatusLabel(entry),
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                            ),
                            if (entry.userName != null) TextSpan(text: ' · ${entry.userName}'),
                            if ((entry.reason ?? '').isNotEmpty) TextSpan(text: ' · ${entry.reason}'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_isCancellingAttention) ...[
            const SizedBox(height: 12),
            ReasonBox(
              controller: _cancelReason,
              label: 'Motivo de la cancelación de la atención',
              hint: 'Ej: los comensales se fueron antes de pedir',
              confirmLabel: 'Cancelar atención',
              onCancel: () => setState(() => _isCancellingAttention = false),
              onConfirm: _confirmCancelAttention,
            ),
          ],
        ],
      ),
    );
  }

  Widget _productTile(BuildContext context, SessionStore session, OrderedProduct product) {
    final c = context.colors;
    final billable = isBillableProduct(product.status);
    final reasonFor = _reasonFor;
    final askingReason = reasonFor?.productId == product.id;
    final canManage = session.can('orders.manage');
    final nextLabel = nextOrderedProductActionLabel(product.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
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
                      '${product.quantity}× ${product.name}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: billable ? c.onSurface : c.onSurfaceVariant,
                        decoration: billable ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    if (product.notes.isNotEmpty)
                      Text(
                        'Nota: ${product.notes}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.tertiary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMoney(product.subtotal, widget.currency),
                style: tabular(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                tone: orderedProductStatusTone[product.status] ?? 'neutral',
                label: orderedProductStatusLabel[product.status] ?? product.status,
              ),
              if (_isActive && !askingReason)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (canManage && canRejectOrderedProduct(product.status))
                      BaseButton(label: 'Rechazar', variant: 'danger-soft', size: 'sm', onPressed: () => _askReason(product, 'rejected'))
                    else if (canManage && canCancelOrderedProduct(product.status))
                      BaseButton(label: 'Cancelar', size: 'sm', onPressed: () => _askReason(product, 'cancelled')),
                    if (_canAdvance(session, product) && nextLabel != null)
                      BaseButton(
                        label: nextLabel,
                        variant: 'primary',
                        size: 'sm',
                        disabled: _busyId == product.id,
                        onPressed: () => _advance(product),
                      ),
                  ],
                ),
            ],
          ),
          if ((product.rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Motivo: ${product.rejectionReason}', style: TextStyle(fontSize: 12, color: c.error)),
          ],
          if (askingReason) ...[
            const SizedBox(height: 8),
            ReasonBox(
              controller: _reason,
              label: reasonFor!.action == 'rejected' ? 'Motivo del rechazo' : 'Motivo de la cancelación',
              hint: 'Ej: producto agotado',
              confirmLabel: 'Confirmar',
              busy: _busyId == product.id,
              onCancel: () => setState(() => _reasonFor = null),
              onConfirm: () => _confirmReason(product),
            ),
          ],
        ],
      ),
    );
  }
}
