import '../../core/utils/json.dart';
import 'order_status_labels.dart';
import 'types.dart';

class OrderRound {
  const OrderRound({required this.batchId, required this.requestedAt, this.createdBy, required this.products});

  final String batchId;
  final String requestedAt;

  /// Empleado que lo cargó; null si lo pidió el comensal por QR.
  final String? createdBy;
  final List<OrderedProduct> products;

  factory OrderRound.fromJson(JsonMap json) => OrderRound(
    batchId: asString(json['batchId']),
    requestedAt: asString(json['requestedAt']),
    createdBy: asStringOrNull(json['createdBy']),
    products: asMapList(json['products']).map(OrderedProduct.fromJson).toList(),
  );

  JsonMap toJson() => {
    'batchId': batchId,
    'requestedAt': requestedAt,
    'createdBy': createdBy,
    'products': products.map((product) => product.toJson()).toList(),
  };
}

/// Agrupa los productos por ronda (cada envío del carrito o pedido manual), de la más antigua a la más reciente.
List<OrderRound> groupByRound(List<OrderedProduct> products) {
  final rounds = <String, OrderRound>{};

  for (final product in products) {
    final round = rounds[product.batchId];

    if (round != null) {
      round.products.add(product);
    } else {
      rounds[product.batchId] = OrderRound(
        batchId: product.batchId,
        requestedAt: product.requestedAt,
        createdBy: product.createdBy,
        products: [product],
      );
    }
  }

  return rounds.values.toList()..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
}

/// Momento en que cada producto llegó a su estado actual, según el historial.
Map<String, String> statusSinceMap(List<StatusHistoryEntry> history) {
  final since = <String, String>{};

  for (final entry in history) {
    if (entry.entityType == 'orderedProduct') {
      since[entry.entityId] = entry.changedAt;
    }
  }

  return since;
}

String historyStatusLabel(StatusHistoryEntry entry) {
  if (entry.entityType == 'attention') {
    return attentionStatusLabel[entry.toStatus] ?? entry.toStatus;
  }

  return orderedProductStatusLabel[entry.toStatus] ?? entry.toStatus;
}

/// Minutos sin confirmar a partir de los cuales un pedido entrante se marca como demorado.
const int incomingDelayMinutes = 5;

/// Minutos en cocina a partir de los cuales una comanda se marca como demorada.
const int kitchenDelayMinutes = 15;

/// Minutos esperando en el pase a partir de los cuales una entrega se marca como demorada.
const int deliveryDelayMinutes = 5;

/// 'ok' | 'warning' | 'critical'
typedef DelayLevel = String;

/// Normal por debajo del umbral, aviso al superarlo y crítico al doble: así el rojo sigue significando algo.
DelayLevel delayLevel(num minutes, num threshold) {
  if (minutes >= threshold * 2) {
    return 'critical';
  }

  return minutes >= threshold ? 'warning' : 'ok';
}

const Map<DelayLevel, String> delayRingClass = {'ok': 'ring-transparent', 'warning': 'ring-warning', 'critical': 'ring-error'};

const Map<DelayLevel, String> delayTextClass = {'ok': 'text-on-surface-variant', 'warning': 'text-warning', 'critical': 'text-error'};

const Map<DelayLevel, String> delayLabel = {'ok': '', 'warning': 'Demorado', 'critical': 'Muy demorado'};
