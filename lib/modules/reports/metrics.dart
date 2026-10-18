import '../../core/utils/json.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time.dart';
import '../orders/order_status_labels.dart';
import '../orders/types.dart';
import '../payments/account.dart';
import '../payments/types.dart';

/// 'today' | 'week' | 'all'
typedef MetricsPeriod = String;

class RankedItem {
  const RankedItem({required this.label, required this.value, this.detail});

  final String label;
  final num value;
  final String? detail;

  factory RankedItem.fromJson(JsonMap json) =>
      RankedItem(label: asString(json['label']), value: asDouble(json['value']), detail: asStringOrNull(json['detail']));

  JsonMap toJson() => {'label': label, 'value': value, if (detail != null) 'detail': detail};
}

class SiteMetrics {
  const SiteMetrics({
    this.minutesToConfirm,
    this.minutesToReady,
    this.minutesToDeliver,
    this.minutesEndToEnd,
    required this.attentionsClosed,
    required this.attentionsCancelled,
    this.averageAttentionMinutes,
    this.tableTurnover,
    required this.sales,
    this.averageTicket,
    required this.topProducts,
    required this.rejectedProducts,
    this.qrShare,
    required this.qrCount,
    required this.manualCount,
  });

  /// Minutos promedio de cada tramo; null si no hay datos suficientes.
  final double? minutesToConfirm;
  final double? minutesToReady;
  final double? minutesToDeliver;
  final double? minutesEndToEnd;
  final int attentionsClosed;
  final int attentionsCancelled;
  final double? averageAttentionMinutes;

  /// Atenciones cerradas por mesa usada en el período.
  final double? tableTurnover;
  final double sales;
  final double? averageTicket;
  final List<RankedItem> topProducts;
  final List<RankedItem> rejectedProducts;
  final int? qrShare;
  final int qrCount;
  final int manualCount;

  factory SiteMetrics.fromJson(JsonMap json) => SiteMetrics(
        minutesToConfirm: asDoubleOrNull(json['minutesToConfirm']),
        minutesToReady: asDoubleOrNull(json['minutesToReady']),
        minutesToDeliver: asDoubleOrNull(json['minutesToDeliver']),
        minutesEndToEnd: asDoubleOrNull(json['minutesEndToEnd']),
        attentionsClosed: asInt(json['attentionsClosed']),
        attentionsCancelled: asInt(json['attentionsCancelled']),
        averageAttentionMinutes: asDoubleOrNull(json['averageAttentionMinutes']),
        tableTurnover: asDoubleOrNull(json['tableTurnover']),
        sales: asDouble(json['sales']),
        averageTicket: asDoubleOrNull(json['averageTicket']),
        topProducts: asMapList(json['topProducts']).map(RankedItem.fromJson).toList(),
        rejectedProducts: asMapList(json['rejectedProducts']).map(RankedItem.fromJson).toList(),
        qrShare: asIntOrNull(json['qrShare']),
        qrCount: asInt(json['qrCount']),
        manualCount: asInt(json['manualCount']),
      );

  JsonMap toJson() => {
        'minutesToConfirm': minutesToConfirm,
        'minutesToReady': minutesToReady,
        'minutesToDeliver': minutesToDeliver,
        'minutesEndToEnd': minutesEndToEnd,
        'attentionsClosed': attentionsClosed,
        'attentionsCancelled': attentionsCancelled,
        'averageAttentionMinutes': averageAttentionMinutes,
        'tableTurnover': tableTurnover,
        'sales': sales,
        'averageTicket': averageTicket,
        'topProducts': topProducts.map((item) => item.toJson()).toList(),
        'rejectedProducts': rejectedProducts.map((item) => item.toJson()).toList(),
        'qrShare': qrShare,
        'qrCount': qrCount,
        'manualCount': manualCount,
      };
}

double _minutesBetween(String from, String to) =>
    (parseIso(to).millisecondsSinceEpoch - parseIso(from).millisecondsSinceEpoch) / 60000;

double? _average(List<double> values) =>
    values.isEmpty ? null : (values.fold<double>(0, (sum, value) => sum + value) / values.length * 10).roundToDouble() / 10;

/// ¿El instante cae dentro del período, según la zona horaria de la sede?
bool isInPeriod(String isoDate, MetricsPeriod period, String timeZone, [DateTime? now]) {
  if (period == 'all') {
    return true;
  }

  final current = now ?? DateTime.now();
  final today = localDateKey(current.toUtc().toIso8601String(), timeZone);
  final day = localDateKey(isoDate, timeZone);

  if (period == 'today') {
    return day == today;
  }

  final weekAgo = localDateKey(current.subtract(const Duration(days: 6)).toUtc().toIso8601String(), timeZone);
  return day.compareTo(weekAgo) >= 0 && day.compareTo(today) <= 0;
}

/// Primer momento en que cada producto llegó a cada estado, según el historial.
Map<String, Map<String, String>> _firstTimes(List<StatusHistoryEntry> history) {
  final times = <String, Map<String, String>>{};

  for (final entry in history) {
    if (entry.entityType != 'orderedProduct') {
      continue;
    }

    times.putIfAbsent(entry.entityId, () => <String, String>{}).putIfAbsent(entry.toStatus, () => entry.changedAt);
  }

  return times;
}

class _Rejection {
  int count = 0;
  final Set<String> reasons = <String>{};
}

SiteMetrics computeSiteMetrics({
  required List<Attention> attentions,
  required List<OrderedProduct> products,
  required List<StatusHistoryEntry> history,
  required List<Payment> payments,
  required MetricsPeriod period,
  required String timeZone,
}) {
  final periodAttentions = attentions.where((attention) => isInPeriod(attention.openedAt, period, timeZone)).toList();
  final attentionIds = periodAttentions.map((attention) => attention.id).toSet();
  final periodProducts = products.where((product) => attentionIds.contains(product.attentionId)).toList();
  final times = _firstTimes(history);

  final toConfirm = <double>[];
  final toReady = <double>[];
  final toDeliver = <double>[];
  final endToEnd = <double>[];

  for (final product in periodProducts) {
    final byStatus = times[product.id];
    final sent = byStatus?['sent'] ?? product.requestedAt;
    // Confirmar un pedido lo pasa directo a cocina: el momento de "en preparación" es la confirmación.
    final confirmed = byStatus?['preparing'];
    final ready = byStatus?['ready'];
    final delivered = byStatus?['delivered'];

    if (confirmed != null && (byStatus?.containsKey('sent') ?? false)) {
      toConfirm.add(_minutesBetween(sent, confirmed));
    }

    if (confirmed != null && ready != null) {
      toReady.add(_minutesBetween(confirmed, ready));
    }

    if (ready != null && delivered != null) {
      toDeliver.add(_minutesBetween(ready, delivered));
    }

    if (delivered != null) {
      endToEnd.add(_minutesBetween(product.requestedAt, delivered));
    }
  }

  final closed = periodAttentions.where((attention) => attention.status == 'closed').toList();
  final durations = closed
      .where((attention) => attention.closedAt != null && attention.closedAt!.isNotEmpty)
      .map((attention) => _minutesBetween(attention.openedAt, attention.closedAt ?? attention.openedAt))
      .toList();
  final tablesUsed = periodAttentions.map((attention) => attention.tableNumber).toSet().length;

  final closedIds = closed.map((attention) => attention.id).toSet();
  final paidByAttention = <String, double>{};

  for (final payment in payments.where((item) => countsAsPaid(item) && closedIds.contains(item.attentionId))) {
    paidByAttention[payment.attentionId] = (paidByAttention[payment.attentionId] ?? 0) + payment.amount;
  }

  final sales = roundMoney(paidByAttention.values.fold<double>(0, (sum, value) => sum + value));
  final ticketValues = paidByAttention.values.where((value) => value > 0).toList();

  final quantities = <String, int>{};
  final rejections = <String, _Rejection>{};

  for (final product in periodProducts) {
    if (isBillableProduct(product.status)) {
      quantities[product.name] = (quantities[product.name] ?? 0) + product.quantity;
    } else if (product.status == 'rejected') {
      final current = rejections.putIfAbsent(product.name, _Rejection.new);
      current.count += product.quantity;

      final reason = product.rejectionReason;
      if (reason != null && reason.isNotEmpty) {
        current.reasons.add(reason);
      }
    }
  }

  final qrCount = periodProducts.where((product) => product.createdBy == null).length;
  final manualCount = periodProducts.length - qrCount;

  final topProducts = quantities.entries.map((entry) => RankedItem(label: entry.key, value: entry.value)).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final rejectedProducts = rejections.entries
      .map((entry) => RankedItem(label: entry.key, value: entry.value.count, detail: entry.value.reasons.join(' · ')))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return SiteMetrics(
    minutesToConfirm: _average(toConfirm),
    minutesToReady: _average(toReady),
    minutesToDeliver: _average(toDeliver),
    minutesEndToEnd: _average(endToEnd),
    attentionsClosed: closed.length,
    attentionsCancelled: periodAttentions.where((attention) => attention.status == 'cancelled').length,
    averageAttentionMinutes: _average(durations),
    tableTurnover: tablesUsed == 0 ? null : (closed.length / tablesUsed * 10).roundToDouble() / 10,
    sales: sales,
    averageTicket: ticketValues.isEmpty ? null : roundMoney(sales / ticketValues.length),
    topProducts: topProducts.take(8).toList(),
    rejectedProducts: rejectedProducts.take(8).toList(),
    qrShare: periodProducts.isEmpty ? null : (qrCount / periodProducts.length * 100).round(),
    qrCount: qrCount,
    manualCount: manualCount,
  );
}

/// Total de cobros de un método de pago en el día.
class DailyClosingMethodTotal {
  const DailyClosingMethodTotal({required this.method, required this.amount, required this.count});

  final PaymentMethod method;
  final double amount;
  final int count;

  factory DailyClosingMethodTotal.fromJson(JsonMap json) =>
      DailyClosingMethodTotal(method: asString(json['method']), amount: asDouble(json['amount']), count: asInt(json['count']));

  JsonMap toJson() => {'method': method, 'amount': amount, 'count': count};
}

/// Total cobrado por un empleado en el día.
class DailyClosingEmployeeTotal {
  const DailyClosingEmployeeTotal({required this.name, required this.amount, required this.count});

  final String name;
  final double amount;
  final int count;

  factory DailyClosingEmployeeTotal.fromJson(JsonMap json) =>
      DailyClosingEmployeeTotal(name: asString(json['name']), amount: asDouble(json['amount']), count: asInt(json['count']));

  JsonMap toJson() => {'name': name, 'amount': amount, 'count': count};
}

class DailyClosingSummary {
  const DailyClosingSummary({
    required this.dateKey,
    required this.open,
    required this.closed,
    required this.cancelled,
    required this.openAttentions,
    required this.totalPaid,
    required this.byMethod,
    required this.byEmployee,
    required this.pendingPayments,
  });

  final String dateKey;
  final int open;
  final int closed;
  final int cancelled;
  final List<Attention> openAttentions;
  final double totalPaid;
  final List<DailyClosingMethodTotal> byMethod;
  final List<DailyClosingEmployeeTotal> byEmployee;
  final int pendingPayments;
}

class _Accumulator {
  double amount = 0;
  int count = 0;
}

/// Resumen de caja de un día local de la sede.
DailyClosingSummary computeDailyClosing({
  required List<Attention> attentions,
  required List<Payment> payments,
  required String dateKey,
  required String timeZone,
}) {
  final dayAttentions = attentions.where((attention) {
    final closedAt = attention.closedAt;
    return localDateKey(attention.openedAt, timeZone) == dateKey ||
        (closedAt != null && localDateKey(closedAt, timeZone) == dateKey);
  }).toList();
  final siteAttentionIds = attentions.map((attention) => attention.id).toSet();
  final dayPayments = payments
      .where((payment) => siteAttentionIds.contains(payment.attentionId) && localDateKey(payment.createdAt, timeZone) == dateKey)
      .toList();
  final paid = dayPayments.where(countsAsPaid).toList();

  final byMethod = <PaymentMethod, _Accumulator>{};
  final byEmployee = <String, _Accumulator>{};

  for (final payment in paid) {
    final method = byMethod.putIfAbsent(payment.method, _Accumulator.new);
    method.amount += payment.amount;
    method.count += 1;

    final employee = byEmployee.putIfAbsent(payment.processedByEmployeeName ?? 'Sin registrar', _Accumulator.new);
    employee.amount += payment.amount;
    employee.count += 1;
  }

  final openAttentions =
      dayAttentions.where((attention) => attention.status == 'open' || attention.status == 'account-requested').toList();

  return DailyClosingSummary(
    dateKey: dateKey,
    open: openAttentions.length,
    closed: dayAttentions.where((attention) => attention.status == 'closed').length,
    cancelled: dayAttentions.where((attention) => attention.status == 'cancelled').length,
    openAttentions: openAttentions,
    totalPaid: roundMoney(paid.fold<double>(0, (sum, payment) => sum + payment.amount)),
    byMethod: byMethod.entries
        .map((entry) => DailyClosingMethodTotal(method: entry.key, amount: roundMoney(entry.value.amount), count: entry.value.count))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount)),
    byEmployee: byEmployee.entries
        .map((entry) => DailyClosingEmployeeTotal(name: entry.key, amount: roundMoney(entry.value.amount), count: entry.value.count))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount)),
    pendingPayments: dayPayments.where((payment) => payment.status == 'pending' || payment.status == 'processing').length,
  );
}
