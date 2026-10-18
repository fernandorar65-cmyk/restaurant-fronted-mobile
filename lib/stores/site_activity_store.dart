import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../modules/orders/api.dart';
import '../modules/orders/types.dart';
import 'session_store.dart';
import 'toast_store.dart';

const Duration _pollInterval = Duration(seconds: 8);

class SiteActivityCounts {
  const SiteActivityCounts({required this.incoming, required this.kitchen, required this.ready, required this.accountRequested});

  /// Productos enviados por comensales o mozos, sin confirmar.
  final int incoming;

  /// Productos confirmados o en preparación.
  final int kitchen;

  /// Productos listos para llevar a la mesa.
  final int ready;

  /// Atenciones con la cuenta solicitada.
  final int accountRequested;

  static const empty = SiteActivityCounts(incoming: 0, kitchen: 0, ready: 0, accountRequested: 0);
}

class _TableProduct {
  const _TableProduct(this.product, this.table);

  final OrderedProduct product;
  final String table;
}

class _Seen {
  const _Seen({required this.sent, required this.preparing, required this.ready, required this.account});

  final Set<String> sent;
  final Set<String> preparing;
  final Set<String> ready;
  final Set<String> account;
}

/// Vigila la actividad de la sede abierta en el portal y avisa al personal según
/// su rol. Sustituye a Socket.IO mientras el backend sea json-server.
/// Consulta cada 8 s y se pausa mientras la app está en segundo plano.
class SiteActivityStore extends ChangeNotifier with WidgetsBindingObserver {
  SiteActivityStore(this.session, this.toast) {
    WidgetsBinding.instance.addObserver(this);
  }

  final SessionStore session;
  final ToastStore toast;

  String? restaurantId;
  SiteActivityCounts counts = SiteActivityCounts.empty;

  /// Aumenta cada vez que cambia algo en la sede; las vistas lo observan para recargar.
  int revision = 0;

  Timer? _timer;
  _Seen? _seen;
  String _lastSignature = '';
  bool _foreground = true;

  Future<void> _refresh() async {
    final id = restaurantId;

    if (id == null) {
      return;
    }

    final attentions = await fetchAttentionsWithProductsBySite(id);

    if (restaurantId != id) {
      return;
    }

    // Solo cuenta lo que sigue en curso: lo de atenciones cerradas o canceladas ya no requiere acción.
    final products = attentions
        .where(isAttentionActive)
        .expand((attention) => attention.products.map((product) => _TableProduct(product, attention.tableNumber)))
        .toList();
    final sent = products.where((item) => item.product.status == 'sent').toList();
    final preparing = products.where((item) => item.product.status == 'preparing').toList();
    final ready = products.where((item) => item.product.status == 'ready').toList();
    final accountRequested = attentions.where((attention) => attention.status == 'account-requested').toList();

    counts = SiteActivityCounts(
      incoming: sent.length,
      kitchen: preparing.length,
      ready: ready.length,
      accountRequested: accountRequested.length,
    );

    final signature = jsonEncode([
      attentions.map((attention) => [attention.id, attention.status]).toList(),
      products.map((item) => [item.product.id, item.product.status]).toList(),
    ]);

    if (signature != _lastSignature) {
      _lastSignature = signature;
      revision += 1;
    }

    final seen = _seen;

    if (seen != null) {
      final newSent = sent.where((item) => !seen.sent.contains(item.product.id)).toList();
      final newInKitchen = preparing.where((item) => !seen.preparing.contains(item.product.id)).toList();
      final newReady = ready.where((item) => !seen.ready.contains(item.product.id)).toList();
      final newAccounts = accountRequested.where((attention) => !seen.account.contains(attention.id)).toList();
      String tables(List<_TableProduct> items) => items.map((item) => item.table).toSet().join(', ');

      if (newSent.isNotEmpty && session.can('orders.manage')) {
        toast.show(
          'Nuevo pedido · Mesa ${tables(newSent)}',
          message: '${newSent.length} producto(s) esperando confirmación.',
          tone: 'warning',
          sound: true,
        );
      }

      if (newInKitchen.isNotEmpty && session.can('kitchen.manage')) {
        toast.show(
          'Nueva comanda en cocina · Mesa ${tables(newInKitchen)}',
          message: '${newInKitchen.length} producto(s) para preparar.',
          sound: true,
        );
      }

      if (newReady.isNotEmpty && session.can('orders.manage')) {
        toast.show(
          'Listo para servir · Mesa ${tables(newReady)}',
          message: '${newReady.length} producto(s) esperan en el pase.',
          tone: 'success',
          sound: true,
        );
      }

      if (newAccounts.isNotEmpty && session.can('payments.manage')) {
        toast.show(
          'Cuenta solicitada · Mesa ${newAccounts.map((attention) => attention.tableNumber).join(', ')}',
          tone: 'warning',
          sound: true,
        );
      }
    }

    _seen = _Seen(
      sent: sent.map((item) => item.product.id).toSet(),
      preparing: preparing.map((item) => item.product.id).toSet(),
      ready: ready.map((item) => item.product.id).toSet(),
      account: accountRequested.map((attention) => attention.id).toSet(),
    );

    notifyListeners();
  }

  /// Relee la actividad de la sede. Un error de red puntual se ignora: se reintenta en el próximo ciclo.
  Future<void> refresh() async {
    try {
      await _refresh();
    } catch (_) {
      // Error de red puntual: se reintenta en el próximo ciclo.
    }
  }

  void watchSite(String? nextRestaurantId) {
    if (restaurantId == nextRestaurantId) {
      return;
    }

    stop();
    restaurantId = nextRestaurantId;
    counts = SiteActivityCounts.empty;
    _seen = null;
    _lastSignature = '';
    notifyListeners();

    if (nextRestaurantId == null) {
      return;
    }

    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) {
      if (_foreground) {
        unawaited(refresh());
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;

    // Al volver a primer plano se pone al día sin esperar al próximo ciclo.
    if (_foreground && !wasForeground && _timer != null) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
