import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../router/routes.dart';
import '../../../stores/cart_store.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/empty_state.dart';
import '../../menus/widgets/quantity_stepper.dart';
import '../api.dart';
import '../types.dart';
import '../../../widgets/base/page_header.dart';

const Map<CartIssueKind, String> _issueLabel = {
  'missing': 'ya no está en la carta',
  'inactive': 'ya no está en la carta',
  'unavailable': 'se agotó',
  'price-changed': 'cambió de precio',
};

/// Carrito del comensal: revisa la orden y la envía a la cocina (con mesa) o pasa al pago.
class CartView extends StatefulWidget {
  const CartView({super.key});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  bool _isSubmitting = false;
  String? _submitError;
  List<CartIssue> _issues = [];
  ({String attentionId, int count})? _sent;
  bool _isCheckingOut = false;

  /// Un controlador por producto para las observaciones (se conserva el cursor al escribir).
  final Map<String, TextEditingController> _notes = {};

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<CartIssue> get _blockingIssues => _issues.where((issue) => issue.kind != 'price-changed').toList();

  List<CartIssue> get _priceIssues => _issues.where((issue) => issue.kind == 'price-changed').toList();

  TextEditingController _notesFor(CartItem item) {
    return _notes.putIfAbsent(item.productId, () => TextEditingController(text: item.notes));
  }

  void _removeUnavailable() {
    final cart = context.read<CartStore>();
    for (final issue in _blockingIssues) {
      cart.removeItem(issue.productId);
    }
    setState(() => _issues = _priceIssues);
  }

  void _acceptNewPrices() {
    final cart = context.read<CartStore>();
    for (final issue in _priceIssues) {
      if (issue.currentPrice != null) {
        cart.setPrice(issue.productId, issue.currentPrice!);
      }
    }
    setState(() => _issues = _blockingIssues);
  }

  List<OrderItemCheck> _checks(CartStore cart) =>
      cart.items.map((item) => OrderItemCheck(productId: item.productId, name: item.name, unitPrice: item.price)).toList();

  Future<void> _confirmOrder() async {
    final diner = context.read<DinerStore>();
    final cart = context.read<CartStore>();
    final restaurantId = diner.restaurantId;
    final tableNumber = diner.tableNumber;

    if (restaurantId == null || tableNumber == null || !diner.confirmed || cart.items.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final issues = await validateOrderItems(restaurantId, _checks(cart));
      if (!mounted) return;
      setState(() => _issues = issues);

      if (issues.isNotEmpty) {
        return;
      }

      final attention = await openOrReuseAttention(restaurantId, tableNumber, customerId: diner.customer?.id);

      await addOrderedProducts(
        attention,
        cart.items
            .map(
              (item) => NewOrderedProductInput(
                productId: item.productId,
                name: item.name,
                unitPrice: item.price,
                quantity: item.quantity,
                notes: item.notes.trim(),
              ),
            )
            .toList(),
        OrderBatchOptions(batchId: cart.batchId, createdBy: null, customerId: diner.customer?.id),
      );

      final count = cart.itemCount;
      diner.setAttention(attention.id);
      cart.clear();
      if (mounted) setState(() => _sent = (attentionId: attention.id, count: count));
    } catch (error) {
      // El batchId del carrito se conserva: reintentar no duplica lo que ya llegó.
      if (mounted) {
        setState(() {
          _submitError = error is BusinessRuleError
              ? error.message
              : errorMessage(error, 'No se pudo enviar el pedido. Revisa tu conexión y vuelve a intentarlo.');
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Sin mesa confirmada: revisa la orden contra la carta y pasa a elegir cómo recibir
  /// el pedido (en mesa, llego al local o delivery) antes del método de pago.
  Future<void> _continueToPayment() async {
    final diner = context.read<DinerStore>();
    final cart = context.read<CartStore>();
    final restaurantId = diner.restaurantId;

    if (restaurantId == null || cart.items.isEmpty || _isCheckingOut) {
      return;
    }

    setState(() {
      _isCheckingOut = true;
      _submitError = null;
    });

    try {
      final issues = await validateOrderItems(restaurantId, _checks(cart));
      if (!mounted) return;
      setState(() => _issues = issues);

      if (issues.isNotEmpty) {
        return;
      }

      context.push(Routes.checkoutFulfillment);
    } catch (error) {
      if (mounted) {
        setState(() => _submitError = errorMessage(error, 'No pudimos revisar tu orden. Revisa tu conexión y vuelve a intentarlo.'));
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();
    final cart = context.watch<CartStore>();

    if (_sent != null) {
      return _SentView(
        count: _sent!.count,
        tableNumber: diner.tableNumber,
        onStatus: () => context.go(Routes.orderStatus(_sent!.attentionId)),
        onMenu: () => context.go(diner.menuRoute),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeadingText('Tu ', accent: 'orden', fontSize: 36, height: 1.05),
          const SizedBox(height: 4),
          Text(
            diner.isReadyToOrder
                ? 'Revisa y confirma antes de enviarla a la cocina.'
                : 'Productos de ${diner.restaurantName ?? 'la sede'}.',
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (cart.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          header,
          EmptyState(
            icon: 'inbox',
            title: 'Tu carrito está vacío',
            message: 'Elige productos de la carta para armar tu pedido.',
            child: BaseButton(label: 'Ver la carta', variant: 'primary', onPressed: () => context.go(diner.menuRoute)),
          ),
        ],
      );
    }

    // Se descartan los controladores de productos que ya no están en el carrito.
    final ids = cart.items.map((item) => item.productId).toSet();
    final stale = _notes.keys.where((id) => !ids.contains(id)).toList();
    if (stale.isNotEmpty) {
      final controllers = [for (final id in stale) _notes.remove(id)!];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              header,
              if (_issues.isNotEmpty) ...[
                _IssuesBox(
                  issues: _issues,
                  currency: diner.currency,
                  hasBlocking: _blockingIssues.isNotEmpty,
                  hasPriceChanges: _priceIssues.isNotEmpty,
                  onRemoveUnavailable: _removeUnavailable,
                  onAcceptPrices: _acceptNewPrices,
                ),
                const SizedBox(height: 16),
              ],
              for (final item in cart.items) ...[
                _CartItemCard(
                  item: item,
                  currency: diner.currency,
                  notesController: _notesFor(item),
                  onIncrease: () => cart.setQuantity(item.productId, item.quantity + 1),
                  onDecrease: () => cart.setQuantity(item.productId, item.quantity - 1),
                  onRemove: () => cart.removeItem(item.productId),
                  onNotes: (value) => cart.setNotes(item.productId, value),
                ),
                const SizedBox(height: 12),
              ],
              BaseButton(label: '+ Agregar más productos', block: true, onPressed: () => context.go(diner.menuRoute)),
            ],
          ),
        ),
        _TotalBar(
          itemCount: cart.itemCount,
          subtotal: formatMoney(cart.subtotal, diner.currency),
          submitError: _submitError,
          button: diner.isReadyToOrder
              ? BaseButton(
                  label: _isSubmitting ? 'Enviando pedido…' : (_submitError != null ? 'Reintentar envío' : 'Confirmar pedido'),
                  variant: 'primary',
                  size: 'lg',
                  block: true,
                  loading: _isSubmitting,
                  disabled: _issues.isNotEmpty,
                  onPressed: _confirmOrder,
                )
              : BaseButton(
                  label: 'Continuar al pago',
                  variant: 'primary',
                  size: 'lg',
                  block: true,
                  loading: _isCheckingOut,
                  disabled: _issues.isNotEmpty,
                  onPressed: _continueToPayment,
                ),
        ),
      ],
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({required this.count, required this.tableNumber, required this.onStatus, required this.onMenu});

  final int count;
  final String? tableNumber;
  final VoidCallback onStatus;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: c.successContainer, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 40, color: c.success),
              ),
              const SizedBox(height: 16),
              const HeadingText('¡Pedido ', accent: 'enviado!', fontSize: 30, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'El restaurante recibió tus $count producto(s) para la mesa ${tableNumber ?? ''}. Te avisaremos cuando '
                'estén confirmados y listos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              BaseButton(label: 'Ver cómo va mi pedido', variant: 'primary', size: 'lg', block: true, onPressed: onStatus),
              const SizedBox(height: 12),
              BaseButton(label: 'Seguir viendo la carta', size: 'lg', block: true, onPressed: onMenu),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssuesBox extends StatelessWidget {
  const _IssuesBox({
    required this.issues,
    required this.currency,
    required this.hasBlocking,
    required this.hasPriceChanges,
    required this.onRemoveUnavailable,
    required this.onAcceptPrices,
  });

  final List<CartIssue> issues;
  final String currency;
  final bool hasBlocking;
  final bool hasPriceChanges;
  final VoidCallback onRemoveUnavailable;
  final VoidCallback onAcceptPrices;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: c.onWarningContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Algo cambió en la carta desde que armaste tu pedido:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 14, color: c.onSurface),
                    children: [
                      TextSpan(
                        text: issue.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' ${_issueLabel[issue.kind] ?? ''}'),
                      if (issue.currentPrice != null) TextSpan(text: ' (ahora ${formatMoney(issue.currentPrice!, currency)})'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasBlocking) BaseButton(label: 'Quitar los no disponibles', variant: 'dark', onPressed: onRemoveUnavailable),
                if (hasPriceChanges) BaseButton(label: 'Aceptar precios nuevos', variant: 'dark', onPressed: onAcceptPrices),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.currency,
    required this.notesController,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onNotes,
  });

  final CartItem item;
  final String currency;
  final TextEditingController notesController;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final ValueChanged<String> onNotes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
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
                    Text(item.name, style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
                    Text('${formatMoney(item.price, currency)} c/u', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(formatMoney(item.price * item.quantity, currency), style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              QuantityStepper(quantity: item.quantity, label: item.name, onIncrease: onIncrease, onDecrease: onDecrease),
              const Spacer(),
              BaseButton(label: 'Quitar', variant: 'ghost', onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Observación para ${item.name}',
            child: TextField(
              controller: notesController,
              onChanged: onNotes,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 14, color: c.onSurface),
              decoration: InputDecoration(hintText: 'Observación (ej: sin cebolla, término medio)', fillColor: c.surface, isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.itemCount, required this.subtotal, required this.submitError, required this.button});

  final int itemCount;
  final String subtotal;
  final String? submitError;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Color(0x141B1C1D), blurRadius: 24, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Total estimado · $itemCount producto(s)', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              ),
              Text(subtotal, style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El restaurante confirma cada producto; lo que se rechace no se cobra.',
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
          if (submitError != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(submitError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          button,
        ],
      ),
    );
  }
}
