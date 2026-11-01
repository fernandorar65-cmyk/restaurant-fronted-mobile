import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time.dart';
import '../menus/api.dart';
import '../payments/account.dart';
import '../payments/api.dart';
import '../restaurants/api.dart';
import 'order_status_labels.dart';
import 'types.dart';

/// Un estado cambió en el servidor desde que se cargó la pantalla (otro empleado se adelantó).
class ConflictError implements Exception {
  ConflictError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Regla de negocio incumplida (mesa en mantenimiento, atención cerrada, etc.).
class BusinessRuleError implements Exception {
  BusinessRuleError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Error genérico del API (equivale a `throw new Error(...)` en la web).
class OrdersApiError implements Exception {
  OrdersApiError(this.message);

  final String message;

  @override
  String toString() => message;
}

String errorMessage(Object? error, String fallback) {
  if (error is ConflictError) return error.message;
  if (error is BusinessRuleError) return error.message;

  if (error is HttpError) {
    // status 0 = sin conexión (en la web llega como TypeError de fetch).
    return error.status == 0 ? 'Sin conexión con el servidor. Revisa tu conexión e inténtalo de nuevo.' : error.message;
  }

  return fallback;
}

const List<AttentionStatus> _attentionStatuses = ['open', 'account-requested', 'closed', 'cancelled'];
const List<OrderedProductStatus> _productStatuses = ['sent', 'preparing', 'ready', 'delivered', 'rejected', 'cancelled'];

/// Como `Promise.all` con dos promesas: a diferencia de `(a, b).wait`, relanza el error original
/// (así `errorMessage` sigue reconociendo HttpError / BusinessRuleError).
Future<(A, B)> _both<A, B>(Future<A> a, Future<B> b) async {
  final results = await Future.wait<Object?>([a, b]);
  return (results[0] as A, results[1] as B);
}

bool _isIdLike(Object? value) => value is String || value is num;

bool _isNullableString(Object? value) => value == null || value is String;

bool _isAttention(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isIdLike(value['id']) &&
      _isIdLike(value['restaurantId']) &&
      value['tableNumber'] is String &&
      _attentionStatuses.contains(value['status']) &&
      value['openedAt'] is String &&
      _isNullableString(value['closedAt']) &&
      _isNullableString(value['guestName']);
}

Attention _toAttention(Object? value) => Attention.fromJson(asMap(value));

bool _isOrderedProduct(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isIdLike(value['id']) &&
      _isIdLike(value['attentionId']) &&
      _isIdLike(value['restaurantId']) &&
      value['productId'] is String &&
      value['name'] is String &&
      value['unitPrice'] is num &&
      value['quantity'] is num &&
      value['subtotal'] is num &&
      value['notes'] is String &&
      _productStatuses.contains(value['status']) &&
      _isNullableString(value['rejectionReason']) &&
      value['requestedAt'] is String;
}

OrderedProduct _toOrderedProduct(Object? value) => OrderedProduct.fromJson(asMap(value));

bool _isStatusHistoryEntry(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isIdLike(value['id']) &&
      (value['entityType'] == 'attention' || value['entityType'] == 'orderedProduct') &&
      _isIdLike(value['entityId']) &&
      _isNullableString(value['fromStatus']) &&
      value['toStatus'] is String &&
      _isNullableString(value['userName']) &&
      _isNullableString(value['reason']) &&
      value['changedAt'] is String;
}

StatusHistoryEntry _toStatusHistoryEntry(Object? value) => StatusHistoryEntry.fromJson(asMap(value));

// ── Atenciones ──────────────────────────────────────────────────────────

Future<List<Attention>> _fetchAttentions([Map<String, Object>? where]) async {
  final payload = await http(where == null ? '/attentions' : '/attentions?${whereQuery(where)}');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isAttention).map(_toAttention).toList()..sort((a, b) => b.openedAt.compareTo(a.openedAt));
}

Future<List<Attention>> fetchAllAttentions() => _fetchAttentions();

Future<List<Attention>> fetchAttentionsBySite(String restaurantId) => _fetchAttentions({'restaurantId': restaurantId});

Future<List<Attention>> fetchAttentionsByCustomer(String customerId) => _fetchAttentions({'customerId': customerId});

Future<Attention?> fetchAttentionById(String id) async {
  try {
    final payload = await http('/attentions/$id');
    return _isAttention(payload) ? _toAttention(payload) : null;
  } on HttpError catch (error) {
    if (error.status == 404) {
      return null;
    }

    rethrow;
  }
}

bool isAttentionActive(Attention attention) => attention.status == 'open' || attention.status == 'account-requested';

Future<Attention?> fetchOpenAttentionForTable(String restaurantId, String tableNumber) async {
  final attentions = await fetchAttentionsBySite(restaurantId);
  final active = attentions.where((attention) => attention.tableNumber == tableNumber && isAttentionActive(attention)).toList()
    ..sort((a, b) => a.openedAt.compareTo(b.openedAt));

  return active.isEmpty ? null : active.first;
}

Future<Attention> _createAttention(
  String restaurantId,
  String tableNumber, {
  String? guestName,
  String? customerId,
  String? userName,
}) async {
  final payload = await http(
    '/attentions',
    method: 'POST',
    body: {
      'restaurantId': restaurantId,
      'tableNumber': tableNumber,
      'status': 'open',
      'openedAt': nowIso(),
      'closedAt': null,
      'guestName': guestName,
      'customerId': customerId,
      'cancellationReason': null,
    },
  );

  if (!_isAttention(payload)) {
    throw OrdersApiError('No se pudo abrir la atención de la mesa.');
  }

  final created = _toAttention(payload);
  await _postStatusHistory('attention', created.id, null, 'open', userName, null);
  return created;
}

/// Comprueba que la sede está activa y que la mesa existe y está habilitada para abrir una atención.
Future<void> assertTableCanOpen(String restaurantId, String tableNumber) async {
  final (site, operation) = await _both(fetchRestaurantById(restaurantId), fetchSiteOperation(restaurantId));

  if (site == null) {
    throw BusinessRuleError('La sede no existe.');
  }

  if (!isRestaurantOpen(site)) {
    throw BusinessRuleError('${site.name} no está recibiendo pedidos en este momento.');
  }

  final tables = operation?.tables ?? const [];
  final matches = tables.where((item) => item.number == tableNumber);
  final table = matches.isEmpty ? null : matches.first;

  if (table == null) {
    throw BusinessRuleError('La mesa $tableNumber no existe en esta sede.');
  }

  if (table.status == 'maintenance') {
    throw BusinessRuleError('La mesa $tableNumber está en mantenimiento.');
  }

  if (table.status == 'inactive') {
    throw BusinessRuleError('La mesa $tableNumber está inactiva.');
  }
}

/// Devuelve la atención activa de la mesa o abre una nueva. Garantiza una sola
/// atención activa por mesa: si dos dispositivos abren a la vez, se conserva la
/// más antigua y se cancela la duplicada.
Future<Attention> openOrReuseAttention(String restaurantId, String tableNumber, {String? customerId, String? userName}) async {
  final existing = await fetchOpenAttentionForTable(restaurantId, tableNumber);

  if (existing != null) {
    return existing;
  }

  await assertTableCanOpen(restaurantId, tableNumber);
  final created = await _createAttention(restaurantId, tableNumber, customerId: customerId, userName: userName);
  final winner = await fetchOpenAttentionForTable(restaurantId, tableNumber);

  if (winner != null && winner.id != created.id) {
    await http(
      '/attentions/${created.id}',
      method: 'PATCH',
      body: {'status': 'cancelled', 'closedAt': nowIso(), 'cancellationReason': 'Atención duplicada'},
    );
    return winner;
  }

  return created;
}

Future<Attention> _patchAttention(String id, JsonMap body) async {
  final payload = await http('/attentions/$id', method: 'PATCH', body: body);

  if (!_isAttention(payload)) {
    throw OrdersApiError('No se pudo actualizar la atención.');
  }

  return _toAttention(payload);
}

Future<Attention> _fetchFreshAttention(Attention attention) async {
  final fresh = await fetchAttentionById(attention.id);

  if (fresh == null) {
    throw BusinessRuleError('La atención ya no existe.');
  }

  return fresh;
}

/// El comensal pide la cuenta. Pedirla dos veces no hace nada.
Future<Attention> requestAccount(Attention attention) async {
  final fresh = await _fetchFreshAttention(attention);

  if (fresh.status == 'account-requested') {
    return fresh;
  }

  if (fresh.status != 'open') {
    throw BusinessRuleError('Esta atención ya fue cerrada.');
  }

  final updated = await _patchAttention(fresh.id, {'status': 'account-requested'});
  await _postStatusHistory('attention', fresh.id, fresh.status, 'account-requested', null, null);
  return updated;
}

/// Vuelve a dejar la atención abierta (por ejemplo, si el comensal pide algo más tras pedir la cuenta).
Future<Attention> reopenAttention(Attention attention, String? userName) async {
  final fresh = await _fetchFreshAttention(attention);

  if (fresh.status != 'account-requested') {
    return fresh;
  }

  final updated = await _patchAttention(fresh.id, {'status': 'open'});
  await _postStatusHistory('attention', fresh.id, fresh.status, 'open', userName, 'Nuevo pedido tras solicitar la cuenta');
  return updated;
}

/// Cierra la atención. Solo se permite cuando el saldo pendiente es cero.
Future<Attention> closeAttention(Attention attention, String? userName) async {
  final fresh = await _fetchFreshAttention(attention);

  if (fresh.status == 'closed') {
    return fresh;
  }

  if (!isAttentionActive(fresh)) {
    throw BusinessRuleError('La atención ya no está activa.');
  }

  final (products, payments) = await _both(fetchOrderedProductsByAttention(fresh.id), fetchPaymentsByAttention(fresh.id));

  if (computeAccount(products, payments).remaining > moneyEpsilon) {
    throw BusinessRuleError('No se puede cerrar una cuenta con saldo pendiente.');
  }

  final updated = await _patchAttention(fresh.id, {'status': 'closed', 'closedAt': nowIso()});
  await _postStatusHistory('attention', fresh.id, fresh.status, 'closed', userName, null);
  return updated;
}

/// Cancela la atención completa con motivo. No se permite si ya hay pagos registrados.
Future<Attention> cancelAttention(Attention attention, String? userName, String reason) async {
  if (reason.trim().isEmpty) {
    throw BusinessRuleError('Indica el motivo de la cancelación.');
  }

  final fresh = await _fetchFreshAttention(attention);

  if (!isAttentionActive(fresh)) {
    throw BusinessRuleError('La atención ya no está activa.');
  }

  final payments = await fetchPaymentsByAttention(fresh.id);

  if (payments.any((payment) => payment.status == 'paid')) {
    throw BusinessRuleError('No se puede cancelar una atención con pagos registrados. Reembolsa primero los pagos.');
  }

  final products = await fetchOrderedProductsByAttention(fresh.id);

  for (final product in products.where((item) => isBillableProduct(item.status) && item.status != 'delivered')) {
    await updateOrderedProductStatus(product, 'cancelled', userName, reason);
  }

  final updated = await _patchAttention(fresh.id, {'status': 'cancelled', 'closedAt': nowIso(), 'cancellationReason': reason.trim()});
  await _postStatusHistory('attention', fresh.id, fresh.status, 'cancelled', userName, reason.trim());
  return updated;
}

// ── Productos solicitados ───────────────────────────────────────────────

Future<List<OrderedProduct>> _fetchOrderedProducts([Map<String, Object>? where]) async {
  final payload = await http(where == null ? '/orderedProducts' : '/orderedProducts?${whereQuery(where)}');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isOrderedProduct).map(_toOrderedProduct).toList()..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
}

Future<List<OrderedProduct>> fetchAllOrderedProducts() => _fetchOrderedProducts();

Future<List<OrderedProduct>> fetchOrderedProductsBySite(String restaurantId) => _fetchOrderedProducts({'restaurantId': restaurantId});

Future<List<OrderedProduct>> fetchOrderedProductsByAttention(String attentionId) => _fetchOrderedProducts({'attentionId': attentionId});

/// Productos de varias atenciones en una sola consulta.
Future<List<OrderedProduct>> fetchOrderedProductsByAttentions(List<String> attentionIds) async =>
    attentionIds.isEmpty ? [] : _fetchOrderedProducts({'attentionId': attentionIds});

Future<List<AttentionWithProducts>> fetchAttentionsWithProductsBySite(String restaurantId) async {
  final (attentions, products) = await _both(fetchAttentionsBySite(restaurantId), fetchOrderedProductsBySite(restaurantId));

  return attentions
      .map((attention) => AttentionWithProducts.from(attention, products.where((product) => product.attentionId == attention.id).toList()))
      .toList();
}

/// 'missing' | 'inactive' | 'unavailable' | 'price-changed'
typedef CartIssueKind = String;

class CartIssue {
  const CartIssue({required this.productId, required this.name, required this.kind, this.currentPrice});

  final String productId;
  final String name;
  final CartIssueKind kind;

  /// Precio vigente, cuando cambió.
  final double? currentPrice;

  factory CartIssue.fromJson(JsonMap json) => CartIssue(
    productId: asId(json['productId']),
    name: asString(json['name']),
    kind: asString(json['kind']),
    currentPrice: asDoubleOrNull(json['currentPrice']),
  );

  JsonMap toJson() => {'productId': productId, 'name': name, 'kind': kind, 'currentPrice': currentPrice};
}

/// Producto del carrito a revisar contra la carta (`{ productId, name, unitPrice }` en la web).
class OrderItemCheck {
  const OrderItemCheck({required this.productId, required this.name, required this.unitPrice});

  final String productId;
  final String name;
  final double unitPrice;
}

/// Revisa el carrito contra la carta vigente antes de enviarlo: productos que ya
/// no existen, se desactivaron, se agotaron o cambiaron de precio.
Future<List<CartIssue>> validateOrderItems(String restaurantId, List<OrderItemCheck> items) async {
  final products = await fetchMenuProducts(restaurantId);
  final issues = <CartIssue>[];

  for (final item in items) {
    final matches = products.where((candidate) => candidate.id == item.productId);
    final product = matches.isEmpty ? null : matches.first;

    if (product == null) {
      issues.add(CartIssue(productId: item.productId, name: item.name, kind: 'missing'));
    } else if (!product.isActive) {
      issues.add(CartIssue(productId: item.productId, name: item.name, kind: 'inactive'));
    } else if (!product.isAvailable) {
      issues.add(CartIssue(productId: item.productId, name: item.name, kind: 'unavailable'));
    } else if ((product.price - item.unitPrice).abs() > moneyEpsilon) {
      issues.add(CartIssue(productId: item.productId, name: item.name, kind: 'price-changed', currentPrice: product.price.toDouble()));
    }
  }

  return issues;
}

Future<List<OrderedProduct>> _fetchProductsByBatch(String batchId) async {
  final payload = await http('/orderedProducts?batchId=${encodeQuery(batchId)}');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isOrderedProduct).map(_toOrderedProduct).toList();
}

/// Envía una ronda de productos a una atención activa. El precio y el nombre se
/// toman de la carta vigente (no del cliente). Los pedidos del comensal entran
/// como `sent`; los que carga el personal entran directo como `preparing`. Es idempotente por `batchId`:
/// si un reintento llega con el mismo batchId, solo se crean los que faltan.
Future<List<OrderedProduct>> addOrderedProducts(Attention attention, List<NewOrderedProductInput> items, OrderBatchOptions options) async {
  final fresh = await _fetchFreshAttention(attention);

  if (!isAttentionActive(fresh)) {
    throw BusinessRuleError('No se pueden agregar productos a una atención cerrada o cancelada.');
  }

  final catalog = await fetchMenuProducts(fresh.restaurantId);
  final alreadySent = await _fetchProductsByBatch(options.batchId);
  final created = <OrderedProduct>[...alreadySent];
  final requestedAt = alreadySent.isNotEmpty ? alreadySent.first.requestedAt : nowIso();
  // Un pedido cargado por el personal ya está validado con el comensal: entra directo a cocina.
  final OrderedProductStatus initialStatus = options.createdBy != null && options.createdBy!.isNotEmpty ? 'preparing' : 'sent';

  for (final item in items) {
    if (alreadySent.any((product) => product.productId == item.productId)) {
      continue;
    }

    final matches = catalog.where((candidate) => candidate.id == item.productId);
    final product = matches.isEmpty ? null : matches.first;

    if (product == null || product.restaurantId != fresh.restaurantId) {
      throw BusinessRuleError('"${item.name}" no pertenece a la carta de esta sede.');
    }

    if (!product.isActive || !product.isAvailable) {
      throw BusinessRuleError('"${product.name}" no está disponible.');
    }

    final payload = await http(
      '/orderedProducts',
      method: 'POST',
      body: {
        'attentionId': fresh.id,
        'restaurantId': fresh.restaurantId,
        'productId': product.id,
        'name': product.name,
        'unitPrice': product.price,
        'quantity': item.quantity,
        'subtotal': roundMoney(product.price * item.quantity),
        'notes': item.notes,
        'status': initialStatus,
        'rejectionReason': null,
        'requestedAt': requestedAt,
        'batchId': options.batchId,
        'createdBy': options.createdBy,
        'customerId': options.customerId,
      },
    );

    if (!_isOrderedProduct(payload)) {
      throw OrdersApiError('No se pudo enviar uno de los productos del pedido.');
    }

    final createdProduct = _toOrderedProduct(payload);
    await _postStatusHistory('orderedProduct', createdProduct.id, null, initialStatus, options.createdBy, null);
    created.add(createdProduct);
  }

  if (fresh.status == 'account-requested') {
    await reopenAttention(fresh, options.createdBy);
  }

  return created;
}

/// Cambia el estado de un producto validando la transición y que nadie lo haya
/// cambiado antes (control optimista: se compara con el estado que vio el usuario).
Future<OrderedProduct> updateOrderedProductStatus(
  OrderedProduct product,
  OrderedProductStatus toStatus,
  String? userName, [
  String? reason,
]) async {
  final current = await http('/orderedProducts/${product.id}');

  if (!_isOrderedProduct(current)) {
    throw BusinessRuleError('El producto ya no existe.');
  }

  if ((current as Map)['status'] != product.status) {
    throw ConflictError('"${product.name}" ya cambió de estado (ahora está en otro paso). Se actualizó la pantalla.');
  }

  if (!canTransitionOrderedProduct(product.status, toStatus)) {
    throw BusinessRuleError('Ese cambio de estado no está permitido.');
  }

  final needsReason = toStatus == 'rejected' || toStatus == 'cancelled';

  if (needsReason && (reason == null || reason.trim().isEmpty)) {
    throw BusinessRuleError('Indica el motivo.');
  }

  final payload = await http(
    '/orderedProducts/${product.id}',
    method: 'PATCH',
    body: {'status': toStatus, 'rejectionReason': needsReason ? reason?.trim() : null},
  );

  if (!_isOrderedProduct(payload)) {
    throw OrdersApiError('No se pudo actualizar el estado del producto.');
  }

  await _postStatusHistory('orderedProduct', product.id, product.status, toStatus, userName, reason);

  return _toOrderedProduct(payload);
}

class BulkUpdateFailure {
  const BulkUpdateFailure({required this.product, required this.message});

  final OrderedProduct product;
  final String message;
}

class BulkUpdateResult {
  const BulkUpdateResult({required this.updated, required this.failed});

  final List<OrderedProduct> updated;
  final List<BulkUpdateFailure> failed;
}

/// Cambia varios productos al mismo estado. Los que fallan (conflicto, regla) se informan sin cortar el resto.
Future<BulkUpdateResult> updateOrderedProductsStatus(
  List<OrderedProduct> products,
  OrderedProductStatus toStatus,
  String? userName, [
  String? reason,
]) async {
  final result = BulkUpdateResult(updated: [], failed: []);

  for (final product in products) {
    try {
      result.updated.add(await updateOrderedProductStatus(product, toStatus, userName, reason));
    } catch (error) {
      result.failed.add(BulkUpdateFailure(product: product, message: errorMessage(error, 'No se pudo actualizar.')));
    }
  }

  return result;
}

// ── Historial ───────────────────────────────────────────────────────────

Future<void> _postStatusHistory(
  StatusHistoryEntityType entityType,
  String entityId,
  String? fromStatus,
  String toStatus,
  String? userName,
  String? reason,
) async {
  await http(
    '/statusHistory',
    method: 'POST',
    body: {
      'entityType': entityType,
      'entityId': entityId,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
      'userName': userName,
      'reason': reason,
      'changedAt': nowIso(),
    },
  );
}

Future<List<StatusHistoryEntry>> _fetchStatusHistory([Map<String, Object>? where]) async {
  final payload = await http(where == null ? '/statusHistory' : '/statusHistory?${whereQuery(where)}');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isStatusHistoryEntry).map(_toStatusHistoryEntry).toList()..sort((a, b) => a.changedAt.compareTo(b.changedAt));
}

Future<List<StatusHistoryEntry>> fetchAllStatusHistory() => _fetchStatusHistory();

Future<List<StatusHistoryEntry>> fetchStatusHistory(StatusHistoryEntityType entityType, String entityId) =>
    _fetchStatusHistory({'entityType': entityType, 'entityId': entityId});

/// Historial de varios productos solicitados en una sola consulta.
Future<List<StatusHistoryEntry>> fetchOrderedProductsHistory(List<String> productIds) async =>
    productIds.isEmpty ? [] : _fetchStatusHistory({'entityType': 'orderedProduct', 'entityId': productIds});

/// Solicitudes de cuenta de todas las atenciones (para saber desde cuándo espera cada mesa).
Future<List<StatusHistoryEntry>> fetchAccountRequests() => _fetchStatusHistory({'entityType': 'attention', 'toStatus': 'account-requested'});

/// Historial de la atención y de todos sus productos, en orden cronológico.
Future<List<StatusHistoryEntry>> fetchAttentionTimeline(String attentionId, List<String> productIds) async {
  final ids = productIds.toSet();
  return (await _fetchStatusHistory({'entityId': [attentionId, ...productIds]}))
      .where(
        (entry) =>
            (entry.entityType == 'attention' && entry.entityId == attentionId) ||
            (entry.entityType == 'orderedProduct' && ids.contains(entry.entityId)),
      )
      .toList();
}
