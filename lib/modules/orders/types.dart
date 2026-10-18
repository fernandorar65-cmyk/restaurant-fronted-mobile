import '../../core/utils/json.dart';

/// 'open' | 'account-requested' | 'closed' | 'cancelled'
typedef AttentionStatus = String;

class Attention {
  const Attention({
    required this.id,
    required this.restaurantId,
    required this.tableNumber,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.guestName,
    this.customerId,
    this.cancellationReason,
  });

  final String id;
  final String restaurantId;
  final String tableNumber;
  final AttentionStatus status;
  final String openedAt;
  final String? closedAt;
  final String? guestName;

  /// Cuenta de comensal que abrió la atención (null = invitado).
  final String? customerId;
  final String? cancellationReason;

  factory Attention.fromJson(JsonMap json) => Attention(
    id: asId(json['id']),
    restaurantId: asId(json['restaurantId']),
    tableNumber: asString(json['tableNumber']),
    status: asString(json['status'], 'open'),
    openedAt: asString(json['openedAt']),
    closedAt: asStringOrNull(json['closedAt']),
    guestName: asStringOrNull(json['guestName']),
    customerId: json['customerId'] is String ? json['customerId'] as String : null,
    cancellationReason: json['cancellationReason'] is String ? json['cancellationReason'] as String : null,
  );

  JsonMap toJson() => {
    'id': id,
    'restaurantId': restaurantId,
    'tableNumber': tableNumber,
    'status': status,
    'openedAt': openedAt,
    'closedAt': closedAt,
    'guestName': guestName,
    'customerId': customerId,
    'cancellationReason': cancellationReason,
  };

  Attention copyWith({
    String? id,
    String? restaurantId,
    String? tableNumber,
    AttentionStatus? status,
    String? openedAt,
    String? closedAt,
    String? guestName,
    String? customerId,
    String? cancellationReason,
  }) => Attention(
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    tableNumber: tableNumber ?? this.tableNumber,
    status: status ?? this.status,
    openedAt: openedAt ?? this.openedAt,
    closedAt: closedAt ?? this.closedAt,
    guestName: guestName ?? this.guestName,
    customerId: customerId ?? this.customerId,
    cancellationReason: cancellationReason ?? this.cancellationReason,
  );
}

/// 'sent' | 'preparing' | 'ready' | 'delivered' | 'rejected' | 'cancelled'
typedef OrderedProductStatus = String;

class OrderedProduct {
  const OrderedProduct({
    required this.id,
    required this.attentionId,
    required this.restaurantId,
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    required this.notes,
    required this.status,
    this.rejectionReason,
    required this.requestedAt,
    required this.batchId,
    this.createdBy,
    this.customerId,
  });

  final String id;
  final String attentionId;
  final String restaurantId;
  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final String notes;
  final OrderedProductStatus status;
  final String? rejectionReason;
  final String requestedAt;

  /// Ronda: todos los productos enviados juntos comparten el mismo batchId.
  final String batchId;

  /// Empleado que cargó el pedido manualmente (null = pedido por QR).
  final String? createdBy;
  final String? customerId;

  factory OrderedProduct.fromJson(JsonMap json) {
    final attentionId = asId(json['attentionId']);
    final requestedAt = asString(json['requestedAt']);

    return OrderedProduct(
      id: asId(json['id']),
      attentionId: attentionId,
      restaurantId: asId(json['restaurantId']),
      productId: asId(json['productId']),
      name: asString(json['name']),
      unitPrice: asDouble(json['unitPrice']),
      quantity: asInt(json['quantity']),
      subtotal: asDouble(json['subtotal']),
      notes: asString(json['notes']),
      status: asString(json['status'], 'sent'),
      rejectionReason: asStringOrNull(json['rejectionReason']),
      requestedAt: requestedAt,
      batchId: json['batchId'] is String ? json['batchId'] as String : 'batch-$attentionId-$requestedAt',
      createdBy: json['createdBy'] is String ? json['createdBy'] as String : null,
      customerId: json['customerId'] is String ? json['customerId'] as String : null,
    );
  }

  JsonMap toJson() => {
    'id': id,
    'attentionId': attentionId,
    'restaurantId': restaurantId,
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'subtotal': subtotal,
    'notes': notes,
    'status': status,
    'rejectionReason': rejectionReason,
    'requestedAt': requestedAt,
    'batchId': batchId,
    'createdBy': createdBy,
    'customerId': customerId,
  };

  OrderedProduct copyWith({
    String? id,
    String? attentionId,
    String? restaurantId,
    String? productId,
    String? name,
    double? unitPrice,
    int? quantity,
    double? subtotal,
    String? notes,
    OrderedProductStatus? status,
    String? rejectionReason,
    String? requestedAt,
    String? batchId,
    String? createdBy,
    String? customerId,
  }) => OrderedProduct(
    id: id ?? this.id,
    attentionId: attentionId ?? this.attentionId,
    restaurantId: restaurantId ?? this.restaurantId,
    productId: productId ?? this.productId,
    name: name ?? this.name,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    subtotal: subtotal ?? this.subtotal,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    requestedAt: requestedAt ?? this.requestedAt,
    batchId: batchId ?? this.batchId,
    createdBy: createdBy ?? this.createdBy,
    customerId: customerId ?? this.customerId,
  );
}

class OrderBatchOptions {
  const OrderBatchOptions({required this.batchId, this.createdBy, this.customerId});

  /// Clave de idempotencia: reintentar con el mismo batchId no duplica productos.
  final String batchId;
  final String? createdBy;
  final String? customerId;

  factory OrderBatchOptions.fromJson(JsonMap json) => OrderBatchOptions(
    batchId: asString(json['batchId']),
    createdBy: asStringOrNull(json['createdBy']),
    customerId: asStringOrNull(json['customerId']),
  );

  JsonMap toJson() => {'batchId': batchId, 'createdBy': createdBy, 'customerId': customerId};
}

class NewOrderedProductInput {
  const NewOrderedProductInput({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.notes,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String notes;

  factory NewOrderedProductInput.fromJson(JsonMap json) => NewOrderedProductInput(
    productId: asId(json['productId']),
    name: asString(json['name']),
    unitPrice: asDouble(json['unitPrice']),
    quantity: asInt(json['quantity'], 1),
    notes: asString(json['notes']),
  );

  JsonMap toJson() => {'productId': productId, 'name': name, 'unitPrice': unitPrice, 'quantity': quantity, 'notes': notes};
}

class AttentionWithProducts extends Attention {
  const AttentionWithProducts({
    required super.id,
    required super.restaurantId,
    required super.tableNumber,
    required super.status,
    required super.openedAt,
    super.closedAt,
    super.guestName,
    super.customerId,
    super.cancellationReason,
    required this.products,
  });

  final List<OrderedProduct> products;

  factory AttentionWithProducts.from(Attention attention, List<OrderedProduct> products) => AttentionWithProducts(
    id: attention.id,
    restaurantId: attention.restaurantId,
    tableNumber: attention.tableNumber,
    status: attention.status,
    openedAt: attention.openedAt,
    closedAt: attention.closedAt,
    guestName: attention.guestName,
    customerId: attention.customerId,
    cancellationReason: attention.cancellationReason,
    products: products,
  );

  factory AttentionWithProducts.fromJson(JsonMap json) =>
      AttentionWithProducts.from(Attention.fromJson(json), asMapList(json['products']).map(OrderedProduct.fromJson).toList());

  @override
  JsonMap toJson() => {...super.toJson(), 'products': products.map((product) => product.toJson()).toList()};
}

/// 'attention' | 'orderedProduct'
typedef StatusHistoryEntityType = String;

class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.fromStatus,
    required this.toStatus,
    this.userName,
    this.reason,
    required this.changedAt,
  });

  final String id;
  final StatusHistoryEntityType entityType;
  final String entityId;
  final String? fromStatus;
  final String toStatus;
  final String? userName;
  final String? reason;
  final String changedAt;

  factory StatusHistoryEntry.fromJson(JsonMap json) => StatusHistoryEntry(
    id: asId(json['id']),
    entityType: asString(json['entityType']),
    entityId: asId(json['entityId']),
    fromStatus: asStringOrNull(json['fromStatus']),
    toStatus: asString(json['toStatus']),
    userName: asStringOrNull(json['userName']),
    reason: asStringOrNull(json['reason']),
    changedAt: asString(json['changedAt']),
  );

  JsonMap toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'fromStatus': fromStatus,
    'toStatus': toStatus,
    'userName': userName,
    'reason': reason,
    'changedAt': changedAt,
  };
}
