import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../router/routes.dart';
import '../../../stores/cart_store.dart';
import '../../../stores/checkout_store.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../api.dart';
import '../checkout.dart';
import '../checkout_controller.dart';
import '../widgets/checkout_summary.dart';
import '../widgets/checkout_ui.dart';

/// Paso 2 del checkout: elegir el método de pago.
class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  late final CheckoutController _checkout;
  bool _wasLoading = true;

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

    // Sin productos o sin datos de entrega completos no se puede elegir cómo pagar.
    if (_wasLoading && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_checkout.cart.items.isEmpty) {
          context.go(Routes.cart);
        } else if (_checkout.fulfillmentError != null) {
          context.go(Routes.checkoutFulfillment);
        }
      });
    }

    _wasLoading = loading;
    setState(() {});
  }

  void _continueWithMethod() {
    final method = _checkout.checkout.method;

    if (method != null) {
      context.push(Routes.checkoutMethod(method));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();
    final store = context.watch<CheckoutStore>();
    final loading = _checkout.isLoading;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CheckoutTitle(title: 'Método de pago', subtitle: 'Elige cómo quieres pagar tu orden.'),
                const SizedBox(height: 24),
                if (loading)
                  const SkeletonBlock(rows: 4)
                else ...[
                  CheckoutSummary(
                    total: _checkout.total,
                    deliveryFee: _checkout.deliveryFee,
                    trailing: TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      onPressed: () => context.go(Routes.checkoutFulfillment),
                      child: Text('Cambiar', style: AppFonts.label(fontSize: 14, color: c.primary)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('PAGA CON', style: AppFonts.eyebrow(color: c.outline, fontSize: 12)),
                  const SizedBox(height: 8),
                  for (final method in enabledCheckoutMethods) ...[
                    _MethodOption(
                      method: method,
                      selected: store.method == method,
                      onTap: () => store.setMethod(method),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (!loading)
          CheckoutActionBar(
            children: [
              BaseButton(
                label: store.method != null ? 'Continuar · ${formatMoney(_checkout.total, diner.currency)}' : 'Elige un método de pago',
                variant: 'primary',
                size: 'lg',
                block: true,
                disabled: store.method == null,
                onPressed: _continueWithMethod,
              ),
            ],
          ),
      ],
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({required this.method, required this.selected, required this.onTap});

  final CheckoutMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = checkoutMethodInfo[method];

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: c.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? c.primary : c.outlineVariant.withValues(alpha: 0.4), width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: selected ? c.primary : c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                    child: Icon(checkoutMethodIcon(method), size: 20, color: selected ? c.onPrimary : c.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paymentMethodLabel[method] ?? method,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                        ),
                        if (info != null) Text(info.hint, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? c.primary : null,
                      border: Border.all(color: selected ? c.primary : c.outlineVariant, width: 2),
                    ),
                    child: selected
                        ? Container(width: 8, height: 8, decoration: BoxDecoration(color: c.onPrimary, shape: BoxShape.circle))
                        : null,
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
