import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time.dart';
import '../../widgets/base/status_badge.dart' show StatusTone;
import '../orders/api.dart';
import 'account.dart';
import 'types.dart';

const List<PaymentMethod> paymentMethods = ['cash', 'card', 'yape', 'plin', 'transfer', 'other'];
const List<PaymentStatus> _statuses = ['pending', 'processing', 'paid', 'failed', 'cancelled', 'refunded'];

/// Como `Promise.all` con dos promesas: a diferencia de `(a, b).wait`, relanza el error original
/// (así `errorMessage` sigue reconociendo HttpError / BusinessRuleError).
Future<(A, B)> _both<A, B>(Future<A> a, Future<B> b) async {
  final results = await Future.wait<Object?>([a, b]);
  return (results[0] as A, results[1] as B);
}

bool _isIdLike(Object? value) => value is String || value is num;

bool _isPayment(Object? value) {
  if (value is! Map) {
    return false;
  }

  final payerName = value['payerName'];
  final processedBy = value['processedByEmployeeName'];
  final externalReference = value['externalReference'];

  return _isIdLike(value['id']) &&
      _isIdLike(value['attentionId']) &&
      value['amount'] is num &&
      paymentMethods.contains(value['method']) &&
      _statuses.contains(value['status']) &&
      (payerName == null || payerName is String) &&
      (processedBy == null || processedBy is String) &&
      (externalReference == null || externalReference is String) &&
      value['createdAt'] is String;
}

Payment _toPayment(Object? value) => Payment.fromJson(asMap(value));

Future<List<Payment>> fetchAllPayments() async {
  final payload = await http('/payments');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isPayment).map(_toPayment).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

Future<List<Payment>> fetchPaymentsByAttention(String attentionId) async =>
    (await fetchAllPayments()).where((payment) => payment.attentionId == attentionId).toList();

/// Registra un pago validando contra el estado actual en el servidor:
/// no supera el saldo pendiente, ni lo pendiente de cada producto asignado,
/// y un reintento con el mismo `requestId` no duplica el pago.
Future<Payment> createPayment(CreatePaymentPayload draft) async {
  final duplicated = await http('/payments?requestId=${encodeQuery(draft.requestId)}');

  if (duplicated is List) {
    final existing = duplicated.where(_isPayment);

    if (existing.isNotEmpty) {
      return _toPayment(existing.first);
    }
  }

  final amount = roundMoney(draft.amount);

  if (amount <= 0) {
    throw BusinessRuleError('El monto debe ser mayor que cero.');
  }

  final attention = await fetchAttentionById(draft.attentionId);

  if (attention == null || !isAttentionActive(attention)) {
    throw BusinessRuleError('La atención ya está cerrada o cancelada.');
  }

  final (products, payments) =
      await _both(fetchOrderedProductsByAttention(draft.attentionId), fetchPaymentsByAttention(draft.attentionId));
  final account = computeAccount(products, payments);

  if (draft.status == 'paid' && amount > account.remaining + moneyEpsilon) {
    throw BusinessRuleError('El monto supera el saldo pendiente de la cuenta.');
  }

  var allocated = 0.0;

  for (final allocation in draft.allocations) {
    final matches = account.products.where((item) => item.product.id == allocation.orderedProductId);

    if (matches.isEmpty) {
      throw BusinessRuleError('Uno de los productos no se puede cobrar (rechazado o cancelado).');
    }

    final balance = matches.first;

    if (allocation.amount > balance.pending + moneyEpsilon) {
      throw BusinessRuleError('No se puede asignar a "${balance.product.name}" más de lo que tiene pendiente.');
    }

    allocated += allocation.amount;
  }

  if (draft.allocations.isNotEmpty && (roundMoney(allocated) - amount).abs() > moneyEpsilon) {
    throw BusinessRuleError('La suma asignada a los productos no coincide con el monto del pago.');
  }

  final payload = await http('/payments', method: 'POST', body: {
    ...draft.toJson(),
    'amount': amount,
    'orderedProductIds': draft.allocations.map((item) => item.orderedProductId).toList(),
    'createdAt': nowIso(),
  });

  if (!_isPayment(payload)) {
    throw OrdersApiError('No se pudo registrar el pago.');
  }

  return _toPayment(payload);
}

const Map<PaymentStatus, List<PaymentStatus>> _paymentTransitions = {
  'pending': ['processing', 'paid', 'failed', 'cancelled'],
  'processing': ['paid', 'failed', 'cancelled'],
  'paid': ['refunded'],
  'failed': [],
  'cancelled': [],
  'refunded': [],
};

List<PaymentStatus> nextPaymentStatuses(PaymentStatus status) => _paymentTransitions[status] ?? const [];

Future<Payment> updatePaymentStatus(Payment payment, PaymentStatus status) async {
  if (!nextPaymentStatuses(payment.status).contains(status)) {
    throw BusinessRuleError('Ese cambio de estado del pago no está permitido.');
  }

  if (status == 'paid') {
    final (products, payments) =
        await _both(fetchOrderedProductsByAttention(payment.attentionId), fetchPaymentsByAttention(payment.attentionId));

    if (payment.amount > computeAccount(products, payments).remaining + moneyEpsilon) {
      throw BusinessRuleError('Confirmar este pago superaría el saldo pendiente.');
    }
  }

  final payload = await http('/payments/${payment.id}', method: 'PATCH', body: {'status': status});

  if (!_isPayment(payload)) {
    throw OrdersApiError('No se pudo actualizar el pago.');
  }

  return _toPayment(payload);
}

const Map<PaymentMethod, String> paymentMethodLabel = {
  'cash': 'Efectivo',
  'card': 'Tarjeta',
  'transfer': 'Transferencia',
  'yape': 'Yape',
  'plin': 'Plin',
  'other': 'Otro',
};

const Map<PaymentStatus, String> paymentStatusLabel = {
  'pending': 'Pendiente',
  'processing': 'Procesando',
  'paid': 'Pagado',
  'failed': 'Fallido',
  'cancelled': 'Cancelado',
  'refunded': 'Reembolsado',
};

const Map<PaymentStatus, String> paymentStatusBadgeClass = {
  'pending': 'bg-secondary-container text-on-secondary-container',
  'processing': 'bg-primary-fixed text-on-primary-fixed',
  'paid': 'bg-success-container text-on-success-container',
  'failed': 'bg-error-container text-on-error-container',
  'cancelled': 'bg-surface-container-high text-on-surface-variant',
  'refunded': 'bg-tertiary-fixed text-on-tertiary-container',
};

const Map<PaymentStatus, StatusTone> paymentStatusTone = {
  'pending': 'warning',
  'processing': 'info',
  'paid': 'success',
  'failed': 'danger',
  'cancelled': 'muted',
  'refunded': 'neutral',
};
