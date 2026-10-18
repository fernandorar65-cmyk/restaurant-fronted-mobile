import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/polling.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/diner_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../../widgets/feedback/diner_notice.dart';
import '../../restaurants/api.dart';
import '../api.dart';
import '../order_status_labels.dart';
import '../rounds.dart';
import '../types.dart';

/// Seguimiento del pedido del comensal (/orders/:attentionId). Se actualiza cada 6 s.
class OrderStatusView extends StatefulWidget {
  const OrderStatusView({super.key, required this.attentionId});

  final String attentionId;

  @override
  State<OrderStatusView> createState() => _OrderStatusViewState();
}

class _OrderStatusViewState extends State<OrderStatusView> {
  late final Poller _polling = Poller(_loadAttention, const Duration(seconds: 6));
  Timer? _clock;
  int _now = nowMs();

  Attention? _attention;
  List<OrderedProduct> _products = [];
  late String _currency = context.read<DinerStore>().currency;
  bool _hasConnectionError = false;
  bool _isLoading = true;
  bool _isRequestingAccount = false;
  String? _actionError;
  Map<String, OrderedProductStatus>? _previousStatuses;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = nowMs());
    });
    _start();
  }

  @override
  void didUpdateWidget(covariant OrderStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attentionId != widget.attentionId) {
      _start();
    }
  }

  @override
  void dispose() {
    _polling.dispose();
    _clock?.cancel();
    super.dispose();
  }

  void _start() {
    _previousStatuses = null;
    _attention = null;
    _isLoading = true;

    // Fuera del build: el store avisa a la barra del comensal.
    final id = widget.attentionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final diner = context.read<DinerStore>();
      if (diner.isReadyToOrder && diner.attentionId == null) {
        diner.setAttention(id);
      }
    });

    _loadAttention();
    _polling.start();
  }

  bool get _isActive => _attention != null && isAttentionActive(_attention!);

  bool _isMyTable(DinerStore diner) =>
      _attention != null &&
      diner.isReadyToOrder &&
      diner.restaurantId == _attention!.restaurantId &&
      diner.tableNumber == _attention!.tableNumber;

  double get _total => _products.where((product) => isBillableProduct(product.status)).fold(0, (sum, product) => sum + product.subtotal);

  /// Resumen en una frase de lo más relevante para el comensal ahora mismo.
  ({String tone, String title, String text}) get _summary {
    final active = _products.where((product) => isBillableProduct(product.status)).toList();
    int count(OrderedProductStatus status) => active.where((product) => product.status == status).length;
    final ready = count('ready');
    final preparing = count('preparing');
    final sent = count('sent');

    if (ready > 0) {
      return (
        tone: 'success',
        title: '¡${ready == 1 ? 'Un producto está listo' : '$ready productos están listos'}!',
        text: 'En un momento te los llevan a la mesa.',
      );
    }

    if (preparing > 0) {
      return (tone: 'progress', title: 'Tu pedido se está preparando', text: 'La cocina está con $preparing producto(s).');
    }

    if (sent > 0) {
      return (tone: 'waiting', title: 'Esperando confirmación', text: 'El restaurante está revisando tu pedido.');
    }

    if (active.isNotEmpty) {
      return (tone: 'success', title: 'Todo servido. ¡Buen provecho!', text: '¿Te apetece algo más? Puedes seguir pidiendo.');
    }

    return (tone: 'waiting', title: 'Aún no hay productos', text: 'Elige algo de la carta para empezar.');
  }

  /// Avisa al comensal cuando un producto pasa a listo o es rechazado.
  void _notifyChanges(List<OrderedProduct> next) {
    final previous = _previousStatuses;
    final toast = context.read<ToastStore>();

    if (previous != null) {
      for (final product in next) {
        final before = previous[product.id];

        if (before == product.status) {
          continue;
        }

        if (product.status == 'ready') {
          toast.show(
            '¡${product.name} está listo!',
            message: 'En un momento lo llevan a tu mesa.',
            tone: 'success',
            vibrate: true,
            sound: true,
          );
        } else if (product.status == 'rejected') {
          toast.show(
            '${product.name} no está disponible',
            message: product.rejectionReason ?? 'El restaurante rechazó este producto. No se cobra.',
            tone: 'error',
            vibrate: true,
          );
        } else if (product.status == 'preparing' && before == 'sent') {
          toast.show('${product.name}: confirmado, ya está en cocina', tone: 'info');
        }
      }
    }

    _previousStatuses = {for (final product in next) product.id: product.status};
  }

  Future<void> _loadAttention() async {
    final id = widget.attentionId;

    try {
      final results = await Future.wait([fetchAttentionById(id), fetchOrderedProductsByAttention(id)]);
      final fetchedAttention = results[0] as Attention?;
      final fetchedProducts = results[1] as List<OrderedProduct>;

      if (!mounted || id != widget.attentionId) return;

      if (fetchedAttention != null && (_attention == null || _attention!.restaurantId != fetchedAttention.restaurantId)) {
        final site = await fetchRestaurantById(fetchedAttention.restaurantId);
        _currency = site?.currency ?? _currency;
      }

      if (!mounted) return;

      _notifyChanges(fetchedProducts);
      setState(() {
        _attention = fetchedAttention;
        _products = fetchedProducts;
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
      message: 'Avisaremos al personal para que venga a cobrarte. Si luego quieres algo más, todavía podrás pedirlo.',
      confirmLabel: 'Sí, pedir la cuenta',
    );

    if (!accepted || !mounted) return;

    setState(() {
      _isRequestingAccount = true;
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
      if (mounted) setState(() => _isRequestingAccount = false);
    }
  }

  void _finishVisit() {
    final diner = context.read<DinerStore>();
    if (_isMyTable(diner)) {
      diner.leaveTable();
    }
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();

    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SkeletonBlock(variant: 'list', rows: 4),
      );
    }

    if (_hasConnectionError) {
      return SingleChildScrollView(
        child: DinerNotice(kind: 'connection', onRetry: _loadAttention),
      );
    }

    final attention = _attention;

    if (attention == null) {
      return const SingleChildScrollView(
        child: DinerNotice(
          kind: 'info',
          title: 'No encontramos este pedido',
          message: 'Puede que el enlace no sea correcto. Escanea el QR de tu mesa para empezar.',
        ),
      );
    }

    final rounds = groupByRound(_products);
    final summary = _summary;
    final isMyTable = _isMyTable(diner);
    final (Color summaryBg, Color summaryFg) = switch (summary.tone) {
      'success' => (c.successContainer, c.onSuccessContainer),
      'progress' => (c.primaryFixed, c.onPrimaryFixed),
      _ => (c.surfaceContainer, c.onSurface),
    };

    return RefreshIndicator(
      onRefresh: _loadAttention,
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
                    Text(
                      'Mesa ${attention.tableNumber}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                    ),
                    Text('Tu pedido', style: AppFonts.headline(fontSize: 26, color: c.onSurface)),
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
          if (_isActive && _products.isNotEmpty) ...[
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: summaryBg, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    _PulseDot(color: summaryFg, animate: summary.tone != 'waiting'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(summary.title, style: AppFonts.headline(fontSize: 20, color: summaryFg)),
                          Text(summary.text, style: TextStyle(fontSize: 14, color: summaryFg.withValues(alpha: 0.9))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (attention.status == 'account-requested') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20, color: c.onWarningContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 14, color: c.onWarningContainer),
                        children: const [
                          TextSpan(
                            text: 'Pediste la cuenta.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' El personal ya fue avisado y vendrá a cobrarte. Todavía puedes pedir algo más.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (attention.status == 'closed') ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: c.successContainer, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¡Gracias por tu visita!',
                    textAlign: TextAlign.center,
                    style: AppFonts.headline(fontSize: 24, color: c.onSuccessContainer),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La cuenta de la mesa ${attention.tableNumber} quedó saldada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: c.onSuccessContainer),
                  ),
                  const SizedBox(height: 16),
                  BaseButton(label: 'Ver el detalle', block: true, onPressed: () => context.push(Routes.orderAccount(attention.id))),
                  const SizedBox(height: 8),
                  BaseButton(label: 'Terminar', variant: 'primary', block: true, onPressed: _finishVisit),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else if (attention.status == 'cancelled') ...[
            DinerNotice(
              kind: 'attention-closed',
              title: 'Esta atención fue cancelada',
              message: attention.cancellationReason ?? 'Pide ayuda a un mozo si crees que es un error.',
            ),
            const SizedBox(height: 20),
          ],
          for (var index = 0; index < rounds.length; index++) ...[
            _RoundCard(index: index, round: rounds[index], currency: _currency, now: _now),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: Text('Total (sin productos rechazados)', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                ),
                Text(formatMoney(_total, _currency), style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
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
          if (_isActive) ...[
            const SizedBox(height: 20),
            if (isMyTable) ...[
              BaseButton(label: 'Pedir algo más', size: 'lg', block: true, onPressed: () => context.go(diner.menuRoute)),
              const SizedBox(height: 8),
            ],
            if (attention.status == 'open')
              BaseButton(
                label: 'Solicitar la cuenta',
                variant: 'primary',
                size: 'lg',
                block: true,
                loading: _isRequestingAccount,
                onPressed: _askForAccount,
              )
            else
              BaseButton(
                label: 'Ver la cuenta',
                variant: 'primary',
                size: 'lg',
                block: true,
                onPressed: () => context.go(Routes.orderAccount(attention.id)),
              ),
          ],
        ],
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.index, required this.round, required this.currency, required this.now});

  final int index;
  final OrderRound round;
  final String currency;
  final int now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Ronda ${index + 1}', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
              ),
              Text(formatElapsed(round.requestedAt, now), style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < round.products.length; i++) ...[
            if (i > 0) Divider(height: 24, color: c.outlineVariant.withValues(alpha: 0.4)),
            _ProductProgress(product: round.products[i], currency: currency),
          ],
        ],
      ),
    );
  }
}

class _ProductProgress extends StatelessWidget {
  const _ProductProgress({required this.product, required this.currency});

  final OrderedProduct product;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = orderedProductStatusSteps.indexOf(product.status);
    final billable = isBillableProduct(product.status);
    final done = product.status == 'ready' || product.status == 'delivered';
    final hint = product.status == 'rejected'
        ? (product.rejectionReason ?? orderedProductStatusHint['rejected'] ?? '')
        : (orderedProductStatusHint[product.status] ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: billable ? c.onSurface : c.onSurfaceVariant,
                    decoration: billable ? null : TextDecoration.lineThrough,
                  ),
                  children: [
                    TextSpan(
                      text: '${product.quantity}×',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' ${product.name}'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatMoney(product.subtotal, currency),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.onSurface),
            ),
          ],
        ),
        if (step >= 0) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Progreso de ${product.name}',
            value: '${step + 1} de ${orderedProductStatusSteps.length}',
            child: Row(
              children: [
                for (var position = 0; position < orderedProductStatusSteps.length; position++) ...[
                  if (position > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 6,
                      decoration: BoxDecoration(
                        color: position <= step ? (done ? c.success : c.primary) : c.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(
              tone: orderedProductStatusTone[product.status] ?? 'neutral',
              label: orderedProductStatusLabel[product.status] ?? product.status,
            ),
            if (step >= 0)
              Text(
                'Paso ${step + 1} de ${orderedProductStatusSteps.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurfaceVariant),
              ),
            Text(hint, style: TextStyle(fontSize: 14, color: product.status == 'rejected' ? c.error : c.onSurfaceVariant)),
          ],
        ),
        if (product.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Observación: ${product.notes}', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Punto de estado; con [animate], late suavemente (equivale a `animate-ping`).
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.animate});

  final Color color;
  final bool animate;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.animate)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.scale(
                scale: 1 + _controller.value * 1.2,
                child: Opacity(
                  opacity: 0.4 * (1 - _controller.value),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
