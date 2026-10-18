import '../../core/utils/json.dart';

/// 'cash' | 'card' | 'transfer' | 'yape' | 'plin' | 'other'
typedef PaymentMethod = String;

/// 'pending' | 'processing' | 'paid' | 'failed' | 'cancelled' | 'refunded'
typedef PaymentStatus = String;

/// Parte del pago aplicada a un producto concreto (permite pagar productos específicos o una fracción).
class PaymentAllocation {
  const PaymentAllocation({required this.orderedProductId, required this.amount});

  final String orderedProductId;
  final double amount;

  factory PaymentAllocation.fromJson(JsonMap json) =>
      PaymentAllocation(orderedProductId: asId(json['orderedProductId']), amount: asDouble(json['amount']));

  JsonMap toJson() => {'orderedProductId': orderedProductId, 'amount': amount};
}

class Payment {
  const Payment({
    required this.id,
    required this.attentionId,
    required this.orderedProductIds,
    required this.allocations,
    required this.amount,
    required this.method,
    required this.status,
    this.payerName,
    this.processedByEmployeeName,
    this.externalReference,
    required this.createdAt,
    this.requestId,
  });

  final String id;
  final String attentionId;
  final List<String> orderedProductIds;
  final List<PaymentAllocation> allocations;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? payerName;
  final String? processedByEmployeeName;
  final String? externalReference;
  final String createdAt;

  /// Clave de idempotencia del registro (evita pagos duplicados por reintentos).
  final String? requestId;

  /// Las asignaciones inválidas se descartan y `orderedProductIds` se deriva de ellas.
  factory Payment.fromJson(JsonMap json) {
    final allocations = asMapList(json['allocations'])
        .where((item) => (item['orderedProductId'] is String || item['orderedProductId'] is num) && item['amount'] is num)
        .map(PaymentAllocation.fromJson)
        .toList();

    return Payment(
      id: asId(json['id']),
      attentionId: asId(json['attentionId']),
      orderedProductIds: allocations.map((item) => item.orderedProductId).toList(),
      allocations: allocations,
      amount: asDouble(json['amount']),
      method: asString(json['method'], 'other'),
      status: asString(json['status'], 'pending'),
      payerName: asStringOrNull(json['payerName']),
      processedByEmployeeName: asStringOrNull(json['processedByEmployeeName']),
      externalReference: asStringOrNull(json['externalReference']),
      createdAt: asString(json['createdAt']),
      requestId: json['requestId'] is String ? json['requestId'] as String : null,
    );
  }

  JsonMap toJson() => {
        'id': id,
        'attentionId': attentionId,
        'orderedProductIds': orderedProductIds,
        'allocations': allocations.map((item) => item.toJson()).toList(),
        'amount': amount,
        'method': method,
        'status': status,
        'payerName': payerName,
        'processedByEmployeeName': processedByEmployeeName,
        'externalReference': externalReference,
        'createdAt': createdAt,
        'requestId': requestId,
      };

  Payment copyWith({
    String? id,
    String? attentionId,
    List<String>? orderedProductIds,
    List<PaymentAllocation>? allocations,
    double? amount,
    PaymentMethod? method,
    PaymentStatus? status,
    String? payerName,
    String? processedByEmployeeName,
    String? externalReference,
    String? createdAt,
    String? requestId,
  }) =>
      Payment(
        id: id ?? this.id,
        attentionId: attentionId ?? this.attentionId,
        orderedProductIds: orderedProductIds ?? this.orderedProductIds,
        allocations: allocations ?? this.allocations,
        amount: amount ?? this.amount,
        method: method ?? this.method,
        status: status ?? this.status,
        payerName: payerName ?? this.payerName,
        processedByEmployeeName: processedByEmployeeName ?? this.processedByEmployeeName,
        externalReference: externalReference ?? this.externalReference,
        createdAt: createdAt ?? this.createdAt,
        requestId: requestId ?? this.requestId,
      );
}

class CreatePaymentPayload {
  const CreatePaymentPayload({
    required this.attentionId,
    required this.allocations,
    required this.amount,
    required this.method,
    required this.status,
    this.payerName,
    this.processedByEmployeeName,
    this.externalReference,
    required this.requestId,
  });

  final String attentionId;
  final List<PaymentAllocation> allocations;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? payerName;
  final String? processedByEmployeeName;
  final String? externalReference;
  final String requestId;

  factory CreatePaymentPayload.fromJson(JsonMap json) => CreatePaymentPayload(
        attentionId: asId(json['attentionId']),
        allocations: asMapList(json['allocations']).map(PaymentAllocation.fromJson).toList(),
        amount: asDouble(json['amount']),
        method: asString(json['method'], 'other'),
        status: asString(json['status'], 'pending'),
        payerName: asStringOrNull(json['payerName']),
        processedByEmployeeName: asStringOrNull(json['processedByEmployeeName']),
        externalReference: asStringOrNull(json['externalReference']),
        requestId: asString(json['requestId']),
      );

  JsonMap toJson() => {
        'attentionId': attentionId,
        'allocations': allocations.map((item) => item.toJson()).toList(),
        'amount': amount,
        'method': method,
        'status': status,
        'payerName': payerName,
        'processedByEmployeeName': processedByEmployeeName,
        'externalReference': externalReference,
        'requestId': requestId,
      };
}
