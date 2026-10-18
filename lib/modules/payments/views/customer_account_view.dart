import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/polling.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../stores/diner_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../../widgets/feedback/diner_notice.dart';
import '../../orders/api.dart';
import '../../orders/order_status_labels.dart';
import '../../orders/types.dart';
import '../../restaurants/api.dart';
import '../account.dart';
import '../api.dart';
import '../types.dart';

/// Cuenta del comensal (/orders/:attentionId/cuenta): saldo, consumo y pagos. Se actualiza cada 8 s.
class CustomerAccountView extends StatefulWidget {
  const CustomerAccountView({super.key, required this.attentionId});

  final String attentionId;

  @override
  State<CustomerAccountView> createState() => _CustomerAccountViewState();
}

class _CustomerAccountViewState extends State<CustomerAccountView> {
  late final Poller _polling = Poller(_loadAccount, const Duration(seconds: 8));

  Attention? _attention;
  List<OrderedProduct> _products = [];
  List<Payment> _payments = [];
  late String _currency = context.read<DinerStore>().currency;
  String? _timezone;
  bool _siteLoaded = false;
  bool _isLoading = true;
  bool _hasConnectionError = false;
  bool _isRequesting = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant CustomerAccountView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attentionId != widget.attentionId) {
      _start();
    }
  }

  @override
  void dispose() {
    _polling.dispose();
    super.dispose();
  }

  void _start() {
    _isLoading = true;
    _loadAccount();
    _polling.start();
  }

  Future<void> _loadAccount() async {
    final id = widget.attentionId;

    try {
      final results = await Future.wait([
        fetchAttentionById(id),
        fetchOrderedProductsByAttention(id),
        fetchPaymentsByAttention(id),
      ]);
      final fetchedAttention = results[0] as Attention?;

      if (fetchedAttention != null && !_siteLoaded) {
        final site = await fetchRestaurantById(fetchedAttention.restaurantId);
        _currency = site?.currency ?? _currency;
        _timezone = site?.timezone;
        _siteLoaded = true;
      }

      if (!mounted || id != widget.attentionId) return;

      setState(() {
        _attention = fetchedAttention;
        _products = results[1] as List<OrderedProduct>;
        _payments = results[2] as List<Payment>;
        _hasConnectionError = false;
      });

      if (fetchedAttention != null && !isAttentionActive(fetchedAttention)) {
        _polling.stop();
      }
    } catch (_) {
      if (mounted) setState(() => _hasConnectionError = _attention == null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _askForAccount() async {
    final attention = _attention;
    if (attention == null) return;

    final accepted = await confirmAction(
      context,
      title: '¿Pedir la cuenta?',
      message: 'Avisaremos al personal para que venga a cobrarte.',
      confirmLabel: 'Sí, pedir la cuenta',
    );

    if (!accepted || !mounted) return;

    setState(() {
      _isRequesting = true;
      _actionError = null;
    });

    try {
      final updated = await requestAccount(attention);
      if (!mounted) return;
      setState(() => _attention = updated);
      context.read<ToastStore>().show('Cuenta solicitada', message: 'El personal ya fue avisado.', tone: 'success');
    } catch (error) {
      if (mounted) setState(() => _actionError = errorMessage(error, 'No se pudo solicitar la cuenta.'));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_isLoading) {
      return const SingleChildScrollView(padding: EdgeInsets.all(16), child: SkeletonBlock(variant: 'list', rows: 3));
    }

    if (_hasConnectionError) {
      return SingleChildScrollView(child: DinerNotice(kind: 'connection', onRetry: _loadAccount));
    }

    final attention = _attention;

    if (attention == null) {
      return const SingleChildScrollView(
        child: DinerNotice(kind: 'info', title: 'No encontramos esta cuenta', message: 'Puede que el enlace no sea correcto.'),
      );
    }

    final account = computeAccount(_products, _payments);
    final discarded = _products.where((product) => product.status == 'rejected' || product.status == 'cancelled').toList();
    final tabular = const [FontFeature.tabularFigures()];

    final cardDecoration = BoxDecoration(
      color: c.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
    );
    final divider = Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4));

    return RefreshIndicator(
      onRefresh: _loadAccount,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mesa ${attention.tableNumber}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
                    Text('Tu cuenta', style: AppFonts.headline(fontSize: 26, color: c.onSurface)),
                  ],
                ),
              ),
              StatusBadge(
                size: 'md',
                tone: attentionStatusTone[attention.status] ?? 'neutral',
                label: attentionStatusLabel[attention.status] ?? attention.status,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            label: 'Resumen de la cuenta',
            container: true,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: c.onSurface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo pendiente', style: TextStyle(fontSize: 14, color: c.surface.withValues(alpha: 0.8))),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(account.remaining, _currency),
                    style: AppFonts.headline(fontSize: 36, color: c.surface).copyWith(fontFeatures: tabular),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: c.surface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final (label, amount) in [('Total', account.total), ('Pagado', account.paid)])
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(fontSize: 14, color: c.surface.withValues(alpha: 0.8))),
                              Text(
                                formatMoney(amount, _currency),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.surface, fontFeatures: tabular),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Consumo', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                const SizedBox(height: 8),
                for (final (index, item) in account.products.indexed) ...[
                  if (index > 0) divider,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 16, color: c.onSurface),
                              children: [
                                TextSpan(text: '${item.product.quantity}×', style: const TextStyle(fontWeight: FontWeight.w600)),
                                TextSpan(text: ' ${item.product.name}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatMoney(item.product.subtotal, _currency),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.onSurface, fontFeatures: tabular),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final (index, product) in discarded.indexed) ...[
                  if (index > 0 || account.products.isNotEmpty) divider,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${product.quantity}× ${product.name}',
                            style: TextStyle(fontSize: 16, color: c.onSurfaceVariant, decoration: TextDecoration.lineThrough),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${orderedProductStatusLabel[product.status] ?? product.status} · no se cobra',
                          style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_products.isEmpty)
                  Text('Todavía no hay consumo en esta mesa.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pagos registrados', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                const SizedBox(height: 8),
                if (_payments.isEmpty)
                  Text(
                    'Todavía no hay pagos. El cobro lo registra el personal del restaurante.',
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                  )
                else
                  for (final (index, payment) in _payments.indexed) ...[
                    if (index > 0) divider,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            [
                              formatTime(payment.createdAt, _timezone),
                              paymentMethodLabel[payment.method] ?? payment.method,
                              if (payment.payerName != null) payment.payerName!,
                            ].join(' · '),
                            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBadge(
                                tone: paymentStatusTone[payment.status] ?? 'neutral',
                                label: paymentStatusLabel[payment.status] ?? payment.status,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatMoney(payment.amount, _currency),
                                style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface, fontFeatures: tabular),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
          if (_actionError != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_actionError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
            ),
          ],
          if (attention.status == 'open') ...[
            const SizedBox(height: 20),
            BaseButton(
              label: 'Solicitar la cuenta',
              variant: 'primary',
              size: 'lg',
              block: true,
              loading: _isRequesting,
              onPressed: _askForAccount,
            ),
          ] else if (attention.status == 'account-requested') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(16)),
              child: Text(
                'Cuenta solicitada: el personal vendrá a cobrarte.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.onWarningContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
