import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/cart_store.dart';
import '../../../stores/checkout_store.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../api.dart';
import '../checkout.dart';
import '../checkout_controller.dart';
import '../widgets/checkout_ui.dart';
import '../widgets/methods/card_payment.dart';
import '../widgets/methods/cash_payment.dart';
import '../widgets/methods/transfer_payment.dart';
import '../widgets/methods/wallet_payment.dart';

/// Paso 3 del checkout: el pago con el método elegido (simulado: no hay pasarela).
class PaymentMethodView extends StatefulWidget {
  const PaymentMethodView({super.key, required this.method});

  final String method;

  @override
  State<PaymentMethodView> createState() => _PaymentMethodViewState();
}

class _PaymentMethodViewState extends State<PaymentMethodView> {
  late final CheckoutController _checkout;
  bool _wasLoading = true;
  bool _processing = false;

  CheckoutMethod? get _method => isCheckoutMethod(widget.method) ? widget.method : null;

  String get _title => _method != null ? (paymentMethodLabel[_method] ?? 'Pago') : 'Pago';

  @override
  void initState() {
    super.initState();
    _checkout = CheckoutController(
      diner: context.read<DinerStore>(),
      cart: context.read<CartStore>(),
      checkout: context.read<CheckoutStore>(),
    );
    _checkout.addListener(_onChanged);
  }

  @override
  void dispose() {
    _checkout.removeListener(_onChanged);
    _checkout.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final loading = _checkout.isLoading;

    // Ruta sin método válido, sin productos o con la entrega incompleta: se vuelve al paso que falta.
    if (_wasLoading && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final method = _method;

        if (method == null) {
          context.go(Routes.checkout);
        } else if (_checkout.cart.items.isEmpty) {
          context.go(Routes.cart);
        } else if (_checkout.fulfillmentError != null) {
          context.go(Routes.checkoutFulfillment);
        } else {
          _checkout.checkout.setMethod(method);
        }
      });
    }

    _wasLoading = loading;
    setState(() {});
  }

  String _fulfillmentDetail() {
    final store = _checkout.checkout;
    if (store.mode == 'dine-in') return 'Mesa ${_checkout.diner.tableCode}';
    if (store.mode == 'pickup') {
      return 'Llegada ${store.pickup.arrivalTime} · ${store.pickup.eatIn ? 'Come en el local' : 'Para llevar'}';
    }
    return store.delivery.address;
  }

  String _readyAt() {
    final store = _checkout.checkout;

    if (store.mode == 'pickup') {
      return store.pickup.arrivalTime;
    }

    final minutes = _checkout.prepMinutes + (store.mode == 'delivery' ? 20 : 0);
    final date = DateTime.now().add(Duration(minutes: minutes));
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Pago simulado: no hay pasarela ni se registra el pedido en db.json todavía.
  /// Arma el comprobante, vacía la orden y muestra el resultado.
  Future<void> _pay(String paymentDetail) async {
    final method = _method;
    final store = _checkout.checkout;
    final mode = store.mode;

    if (method == null || mode == null || _processing) {
      return;
    }

    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;
    final diner = _checkout.diner;
    final cart = _checkout.cart;
    final prefix = const {'dine-in': 'M', 'pickup': 'R', 'delivery': 'D'}[mode] ?? 'M';

    store.setReceipt(
      CheckoutReceipt(
        code: '$prefix-${1000 + Random().nextInt(9000)}',
        restaurantName: _checkout.site?.name ?? diner.restaurantName ?? '',
        mode: mode,
        fulfillmentDetail: _fulfillmentDetail(),
        methodLabel: paymentMethodLabel[method] ?? method,
        paymentDetail: paymentDetail,
        items: [for (final item in cart.items) CheckoutReceiptItem(name: item.name, quantity: item.quantity, price: item.price)],
        deliveryFee: _checkout.deliveryFee,
        total: _checkout.total,
        currency: diner.currency,
        readyAt: _readyAt(),
        createdAt: nowIso(),
      ),
    );

    cart.clear();
    store.setMethod(null);
    setState(() => _processing = false);
    context.go(Routes.checkoutResult);
  }

  void _changeMethod() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.checkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();
    final store = context.watch<CheckoutStore>();
    final method = _method;
    final mode = store.mode;
    final amountLabel = formatMoney(_checkout.total, diner.currency);
    final payeeName = 'RentaSol · ${diner.restaurantName ?? ''}'.trim();

    Widget body;

    if (_checkout.isLoading || method == null) {
      body = const SkeletonBlock(rows: 4);
    } else if (method == 'card') {
      body = CardPayment(amountLabel: amountLabel, processing: _processing, onPay: _pay);
    } else if (method == 'yape' || method == 'plin') {
      body = WalletPayment(
        key: ValueKey(method),
        wallet: method,
        amount: _checkout.total,
        amountLabel: amountLabel,
        payeeName: payeeName,
        processing: _processing,
        onPay: _pay,
      );
    } else if (method == 'transfer') {
      body = TransferPayment(amountLabel: amountLabel, payeeName: payeeName, processing: _processing, onPay: _pay);
    } else {
      body = CashPayment(amount: _checkout.total, currency: diner.currency, mode: mode, processing: _processing, onPay: _pay);
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckoutTitle(
            title: 'Pagar con $_title',
            subtitle: mode != null ? '${diner.restaurantName ?? ''} · ${fulfillmentLabel[mode] ?? ''}' : null,
            leading: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: _processing ? null : _changeMethod,
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: c.primary),
                label: Text('Cambiar método', style: AppFonts.label(fontSize: 14, color: c.primary)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          body,
        ],
      ),
    );
  }
}
