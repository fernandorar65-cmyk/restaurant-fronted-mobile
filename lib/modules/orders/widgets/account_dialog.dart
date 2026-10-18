import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../payments/account.dart';
import '../../payments/api.dart';
import '../../payments/types.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../types.dart';
import 'service_ui.dart';

/// Abre la cuenta de una mesa. [source] es la lista viva de atenciones de la vista: la hoja se
/// actualiza cuando la vista recarga (estado de la atención y productos).
Future<void> showAccountDialog(
  BuildContext context, {
  required AttentionWithProducts attention,
  required ValueListenable<List<AttentionWithProducts>> source,
  required String currency,
  String? timezone,
  required Future<void> Function() onChanged,
}) {
  return showServiceSheet<void>(
    context,
    builder: (_) => ValueListenableBuilder<List<AttentionWithProducts>>(
      valueListenable: source,
      builder: (context, list, _) {
        final current = list.where((item) => item.id == attention.id).firstOrNull ?? attention;
        return AccountDialog(attention: current, products: current.products, currency: currency, timezone: timezone, onChanged: onChanged);
      },
    ),
  );
}

/// 'all' | 'amount' | 'products'
typedef _PayMode = String;

const Map<PaymentMethod, String> _methodIcon = {'cash': '💵', 'card': '💳', 'yape': '📱', 'plin': '📲', 'transfer': '🏦', 'other': '➕'};

double _parseAmount(String text) => double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

String _amountText(double value) => value.toStringAsFixed(2);

/// Cuenta de una mesa: detalle cobrable, registro de pagos (todo, un monto o por productos,
/// con división entre personas), historial de pagos y cierre o cancelación de la atención.
class AccountDialog extends StatefulWidget {
  const AccountDialog({
    super.key,
    required this.attention,
    required this.products,
    required this.currency,
    this.timezone,
    required this.onChanged,
  });

  final Attention attention;
  final List<OrderedProduct> products;
  final String currency;
  final String? timezone;
  final Future<void> Function() onChanged;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  List<Payment> _payments = const [];
  bool _isLoadingPayments = true;
  _PayMode _payChoice = 'all';
  final _amount = TextEditingController();

  /// Monto asignado a cada producto en el modo "por productos" (la clave presente = elegido).
  final Map<String, TextEditingController> _allocationDraft = {};
  PaymentMethod _method = 'card';
  bool _isPendingConfirmation = false;
  bool _moreOptionsOpen = false;
  final _payerName = TextEditingController();
  final _externalReference = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;
  bool _isCancelling = false;
  final _cancelReason = TextEditingController();

  /// Se conserva entre reintentos del mismo cobro para no duplicarlo.
  String _requestId = createId('pay');

  @override
  void initState() {
    super.initState();
    _amount.addListener(_refresh);
    _init();
  }

  @override
  void dispose() {
    _amount.dispose();
    _disposeAllocations();
    _payerName.dispose();
    _externalReference.dispose();
    _cancelReason.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _disposeAllocations() {
    final controllers = _allocationDraft.values.toList();
    _allocationDraft.clear();
    // Se liberan cuando sus campos ya salieron del árbol.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  Future<void> _init() async {
    await _loadPayments();
    if (mounted) _amount.text = _amountText(_account.remaining);
  }

  String? get _staffName => context.read<SessionStore>().user?.name;

  AccountSummary get _account => computeAccount(widget.products, _payments);

  bool get _isActive => isAttentionActive(widget.attention);

  double get _allocationTotal =>
      roundMoney(_allocationDraft.values.fold<double>(0, (sum, controller) => sum + _parseAmount(controller.text)));

  double get _amountToCharge {
    if (_payChoice == 'all') {
      return _account.remaining;
    }

    return _payChoice == 'products' ? _allocationTotal : roundMoney(_parseAmount(_amount.text));
  }

  bool get _needsReference => _method != 'cash';

  void _resetForm() {
    _amount.text = _amountText(_account.remaining);
    _disposeAllocations();
    _payerName.clear();
    _externalReference.clear();
    _isPendingConfirmation = false;
    _payChoice = 'all';
    _requestId = createId('pay');
  }

  void _toggleProduct(String productId, double pending) {
    setState(() {
      final existing = _allocationDraft.remove(productId);

      if (existing != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => existing.dispose());
      } else {
        _allocationDraft[productId] = TextEditingController(text: _amountText(pending))..addListener(_refresh);
      }
    });
  }

  /// División monetaria de una misma unidad: asigna al producto su pendiente dividido entre N personas.
  void _splitProduct(String productId, double pending, int parts) {
    if (parts > 0) {
      _allocationDraft[productId]?.text = _amountText(roundMoney(pending / parts));
    }
  }

  void _splitTotal(int parts) {
    if (parts > 0) {
      _amount.text = _amountText(roundMoney(_account.remaining / parts));
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoadingPayments = true);

    try {
      final payments = await fetchPaymentsByAttention(widget.attention.id);
      if (mounted) setState(() => _payments = payments);
    } catch (error) {
      if (mounted) setState(() => _submitError = errorMessage(error, 'No se pudieron cargar los pagos.'));
    } finally {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  Future<void> _closeIfSettled() async {
    final account = _account;

    if (account.remaining <= moneyEpsilon && _isActive && account.total > 0) {
      final toast = context.read<ToastStore>();
      await closeAttention(widget.attention, _staffName);
      toast.show('Cuenta de la mesa ${widget.attention.tableNumber} cerrada', tone: 'success');
      await widget.onChanged();
    }
  }

  Future<void> _registerPayment() async {
    final value = _amountToCharge;

    if (value <= 0) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final payment = await createPayment(
        CreatePaymentPayload(
          attentionId: widget.attention.id,
          allocations: _payChoice == 'products'
              ? [
                  for (final entry in _allocationDraft.entries)
                    if (_parseAmount(entry.value.text) > 0)
                      PaymentAllocation(orderedProductId: entry.key, amount: roundMoney(_parseAmount(entry.value.text))),
                ]
              : const [],
          amount: value,
          method: _method,
          status: _isPendingConfirmation ? 'pending' : 'paid',
          payerName: _payerName.text.trim().isEmpty ? null : _payerName.text.trim(),
          processedByEmployeeName: _staffName,
          externalReference: _externalReference.text.trim().isEmpty ? null : _externalReference.text.trim(),
          requestId: _requestId,
        ),
      );

      if (!mounted) return;
      setState(() {
        _payments = [payment, ..._payments.where((item) => item.id != payment.id)];
        _resetForm();
      });
      await _closeIfSettled();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = errorMessage(error, 'No se pudo registrar el pago.'));
      await _loadPayments();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _changePaymentStatus(Payment payment, PaymentStatus status) async {
    setState(() => _submitError = null);

    try {
      final updated = await updatePaymentStatus(payment, status);
      if (!mounted) return;
      setState(() => _payments = _payments.map((item) => item.id == updated.id ? updated : item).toList());
      await _closeIfSettled();
    } catch (error) {
      if (mounted) setState(() => _submitError = errorMessage(error, 'No se pudo actualizar el pago.'));
    }
  }

  /// Atención sin nada que cobrar (todo rechazado o sin pedidos): se cierra sin pagos.
  Future<void> _closeWithoutCharge() async {
    setState(() => _submitError = null);
    final navigator = Navigator.of(context);

    try {
      await closeAttention(widget.attention, _staffName);
      await widget.onChanged();
      navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _submitError = errorMessage(error, 'No se pudo cerrar la atención.'));
    }
  }

  Future<void> _confirmCancel() async {
    setState(() => _submitError = null);
    final navigator = Navigator.of(context);

    try {
      await cancelAttention(widget.attention, _staffName, _cancelReason.text);
      await widget.onChanged();
      navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _submitError = errorMessage(error, 'No se pudo cancelar la atención.'));
    }
  }

  void _choosePay(_PayMode choice) {
    setState(() {
      _payChoice = choice;
      _disposeAllocations();
      _amount.text = _amountText(_account.remaining);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final account = _account;
    final discarded = widget.products.where((product) => product.status == 'rejected' || product.status == 'cancelled').toList();

    return BaseDialogFrame(
      eyebrow: 'Cuenta de mesa',
      title: 'Mesa ${widget.attention.tableNumber}',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (_isActive && account.paid == 0 && !_isCancelling)
            Material(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _isCancelling = true),
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
          if (_isActive && account.total == 0 && !_isLoadingPayments)
            BaseButton(label: 'Cerrar sin cargo', variant: 'primary', onPressed: _closeWithoutCharge),
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
                tone: attentionStatusTone[widget.attention.status] ?? 'neutral',
                label: attentionStatusLabel[widget.attention.status] ?? widget.attention.status,
              ),
              if (widget.attention.status == 'account-requested')
                Text('El comensal solicitó la cuenta', style: AppFonts.label(fontSize: 12, color: c.tertiary)),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in account.products)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.product.quantity}× ${item.product.name}', style: TextStyle(fontSize: 14, color: c.onSurface)),
                        if (item.allocated > 0)
                          Text(
                            'Pagado ${formatMoney(item.allocated, widget.currency)} · pendiente ${formatMoney(item.pending, widget.currency)}',
                            style: tabular(TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatMoney(item.product.subtotal, widget.currency),
                    style: tabular(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                  ),
                ],
              ),
            ),
          for (final product in discarded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${product.quantity}× ${product.name}',
                      style: TextStyle(fontSize: 14, color: c.onSurfaceVariant, decoration: TextDecoration.lineThrough),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${orderedProductStatusLabel[product.status]} · no se cobra',
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                _summary(context, 'Total', formatMoney(account.total, widget.currency), c.onSurface),
                const SizedBox(width: 10),
                _summary(context, 'Pagado', formatMoney(account.paid, widget.currency), c.success),
                const SizedBox(width: 10),
                _summary(
                  context,
                  'Pendiente',
                  formatMoney(account.remaining, widget.currency),
                  account.remaining > 0 ? c.error : c.onSurface,
                ),
              ],
            ),
          ),
          if (_isActive && account.remaining > moneyEpsilon) ...[const SizedBox(height: 20), _paymentForm(context, account)],
          if (_submitError != null) ...[const SizedBox(height: 16), InlineAlert(_submitError!)],
          if (!_isLoadingPayments && _payments.isNotEmpty) ...[const SizedBox(height: 20), _history(context)],
          if (_isCancelling) ...[
            const SizedBox(height: 16),
            ReasonBox(
              controller: _cancelReason,
              hint: 'Motivo de la cancelación',
              confirmLabel: 'Cancelar atención',
              onCancel: () => setState(() => _isCancelling = false),
              onConfirm: _confirmCancel,
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, String label, String value, Color color) {
    final c = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: AppFonts.label(fontSize: 11, color: c.onSurfaceVariant, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: tabular(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitButton(BuildContext context, int parts, VoidCallback onTap) {
    final c = context.colors;

    return Material(
      color: c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text('$parts', style: AppFonts.label(fontSize: 14, color: c.onSurface)),
          ),
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController controller, {double width = 160, double fontSize = 18}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: tabular(TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
        decoration: const InputDecoration(isDense: true, hintText: '0.00'),
      ),
    );
  }

  Widget _paymentForm(BuildContext context, AccountSummary account) {
    final c = context.colors;
    final amountToCharge = _amountToCharge;
    final payable = account.products.where((item) => item.pending > moneyEpsilon).toList();
    final exceeds = amountToCharge > account.remaining + moneyEpsilon;

    return Semantics(
      container: true,
      label: 'Registrar pago',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. ¿Cuánto paga?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'all', label: Text('Todo')),
                ButtonSegment(value: 'amount', label: Text('Un monto')),
                ButtonSegment(value: 'products', label: Text('Por productos')),
              ],
              selected: {_payChoice},
              onSelectionChanged: (value) => _choosePay(value.first),
            ),
            const SizedBox(height: 10),
            if (_payChoice == 'all')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(12)),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'Se cobra el saldo completo: '),
                      TextSpan(
                        text: formatMoney(account.remaining, widget.currency),
                        style: tabular(TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              )
            else if (_payChoice == 'amount') ...[
              Row(
                children: [
                  Semantics(label: 'Monto', child: _amountField(_amount)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'de ${formatMoney(account.remaining, widget.currency)}',
                      style: tabular(TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Dividir entre', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                  for (final parts in const [2, 3, 4, 5]) _splitButton(context, parts, () => _splitTotal(parts)),
                ],
              ),
            ] else
              for (final item in payable)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _toggleProduct(item.product.id, item.pending),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _allocationDraft.containsKey(item.product.id),
                                onChanged: (_) => _toggleProduct(item.product.id, item.pending),
                              ),
                              Expanded(
                                child: Text(
                                  '${item.product.quantity}× ${item.product.name}',
                                  style: TextStyle(fontSize: 14, color: c.onSurface),
                                ),
                              ),
                              Text(
                                formatMoney(item.pending, widget.currency),
                                style: tabular(TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_allocationDraft[item.product.id] case final controller?)
                        Padding(
                          padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Semantics(
                                label: 'Monto para ${item.product.name}',
                                child: _amountField(controller, width: 112, fontSize: 14),
                              ),
                              Text('Compartir entre', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                              for (final parts in const [2, 3, 4])
                                _splitButton(context, parts, () => _splitProduct(item.product.id, item.pending, parts)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            const SizedBox(height: 20),
            Text(
              '2. ¿Cómo paga?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final width = (constraints.maxWidth - gap * 2) / 3;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final option in paymentMethods)
                      SizedBox(
                        width: width,
                        child: Semantics(
                          inMutuallyExclusiveGroup: true,
                          checked: _method == option,
                          child: Material(
                            color: _method == option ? c.primaryFixed : c.surfaceContainerLowest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: _method == option ? c.primary : Colors.transparent, width: 2),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _method = option),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 56),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ExcludeSemantics(child: Text(_methodIcon[option] ?? '', style: const TextStyle(fontSize: 18))),
                                    Text(
                                      paymentMethodLabel[option] ?? option,
                                      style: AppFonts.label(fontSize: 13, color: _method == option ? c.onPrimaryFixed : c.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_needsReference) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _externalReference,
                decoration: const InputDecoration(hintText: 'N.º de operación (opcional)'),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _moreOptionsOpen = !_moreOptionsOpen),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Más opciones', style: AppFonts.label(fontSize: 14, color: c.onSurfaceVariant)),
                          ),
                          AnimatedRotation(
                            turns: _moreOptionsOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(Icons.expand_more_rounded, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_moreOptionsOpen) ...[
                    TextField(
                      controller: _payerName,
                      decoration: const InputDecoration(hintText: 'Nombre de quien paga'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _isPendingConfirmation,
                      onChanged: (value) => setState(() => _isPendingConfirmation = value ?? false),
                      title: const Text('Todavía no llegó (ej: transferencia por confirmar)', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            BaseButton(
              label:
                  '${_isPendingConfirmation ? 'Registrar como pendiente' : 'Cobrar'} ${formatMoney(amountToCharge, widget.currency)} · ${paymentMethodLabel[_method]}',
              variant: 'primary',
              size: 'lg',
              block: true,
              loading: _isSubmitting,
              disabled: amountToCharge <= 0 || exceeds,
              onPressed: _registerPayment,
            ),
            const SizedBox(height: 8),
            if (exceeds)
              Text(
                'El monto supera el saldo pendiente (${formatMoney(account.remaining, widget.currency)}).',
                style: TextStyle(fontSize: 14, color: c.error),
              )
            else if (amountToCharge > 0 && amountToCharge + moneyEpsilon < account.remaining)
              Text(
                'Quedarán ${formatMoney(account.remaining - amountToCharge, widget.currency)} pendientes.',
                style: tabular(TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              )
            else if (amountToCharge > 0 && !_isPendingConfirmation)
              Text('Con este pago la cuenta queda saldada y se cierra.', style: TextStyle(fontSize: 14, color: c.success)),
          ],
        ),
      ),
    );
  }

  Widget _history(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('HISTORIAL DE PAGOS', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final payment in _payments)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${paymentMethodLabel[payment.method] ?? payment.method}${payment.payerName != null ? ' · ${payment.payerName}' : ''}',
                        style: TextStyle(fontSize: 14, color: c.onSurface),
                      ),
                    ),
                    Text(
                      formatMoney(payment.amount, widget.currency),
                      style: tabular(
                        TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: payment.status == 'paid' ? c.onSurface : c.onSurfaceVariant,
                          decoration: payment.status == 'paid' ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      tone: paymentStatusTone[payment.status] ?? 'neutral',
                      label: paymentStatusLabel[payment.status] ?? payment.status,
                    ),
                    Text(formatTime(payment.createdAt, widget.timezone), style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    if (payment.processedByEmployeeName != null)
                      Text('· ${payment.processedByEmployeeName}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    if (payment.externalReference != null)
                      Text('· Ref. ${payment.externalReference}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    if (payment.allocations.isNotEmpty)
                      Text('· ${payment.allocations.length} producto(s)', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ],
                ),
                if (_isActive && nextPaymentStatuses(payment.status).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final status in nextPaymentStatuses(payment.status))
                        BaseButton(
                          label: 'Marcar ${(paymentStatusLabel[status] ?? status).toLowerCase()}',
                          size: 'sm',
                          onPressed: () => _changePaymentStatus(payment, status),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
