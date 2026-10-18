import 'package:intl/intl.dart';

import '../../core/utils/json.dart';
import 'types.dart';

String _pad(int value) => '$value'.padLeft(2, '0');

/// Fechas locales en formato YYYY-MM-DD (sin desfases de zona horaria).
String toDateKey(DateTime date) => '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

DateTime parseDateKey(String key) {
  final parts = key.split('-').map((part) => int.tryParse(part)).toList();
  final year = parts.isNotEmpty ? parts[0] ?? 1970 : 1970;
  final month = parts.length > 1 ? parts[1] ?? 1 : 1;
  final day = parts.length > 2 ? parts[2] ?? 1 : 1;
  return DateTime(year, month, day);
}

String _addDays(String key, int days) {
  final date = parseDateKey(key);
  // DateTime normaliza el día fuera de rango (y evita saltos por cambio de hora).
  return toDateKey(DateTime(date.year, date.month, date.day + days));
}

class PeriodRange {
  const PeriodRange({required this.from, required this.to});

  final String from;
  final String to;

  factory PeriodRange.fromJson(JsonMap json) => PeriodRange(from: asString(json['from']), to: asString(json['to']));

  JsonMap toJson() => {'from': from, 'to': to};
}

/// Rango del período elegido. `anchor` es una fecha dentro del período.
/// - día: ese día · mes: del 1 al último día · año: de enero a diciembre.
PeriodRange periodRange(FinancePeriodKind period, String anchor) {
  final date = parseDateKey(anchor);

  if (period == 'day') {
    return PeriodRange(from: anchor, to: anchor);
  }

  if (period == 'month') {
    final first = DateTime(date.year, date.month, 1);
    final last = DateTime(date.year, date.month + 1, 0);
    return PeriodRange(from: toDateKey(first), to: toDateKey(last));
  }

  return PeriodRange(from: '${date.year}-01-01', to: '${date.year}-12-31');
}

/// Período con el que se compara: para un día, el mismo día de la semana anterior
/// (en un restaurante un lunes no se compara con un domingo); mes y año, el anterior.
String previousAnchor(FinancePeriodKind period, String anchor) {
  final date = parseDateKey(anchor);

  if (period == 'day') {
    return _addDays(anchor, -7);
  }

  if (period == 'month') {
    return toDateKey(DateTime(date.year, date.month - 1, 1));
  }

  return toDateKey(DateTime(date.year - 1, 1, 1));
}

/// Mueve el período elegido hacia atrás (-1) o adelante (+1).
String shiftAnchor(FinancePeriodKind period, String anchor, int step) {
  final date = parseDateKey(anchor);

  if (period == 'day') {
    return _addDays(anchor, step);
  }

  if (period == 'month') {
    return toDateKey(DateTime(date.year, date.month + step, 1));
  }

  return toDateKey(DateTime(date.year + step, 1, 1));
}

class TimeBucket {
  const TimeBucket({required this.key, required this.label, required this.from, required this.to});

  final String key;
  final String label;
  final String from;
  final String to;

  factory TimeBucket.fromJson(JsonMap json) => TimeBucket(
        key: asString(json['key']),
        label: asString(json['label']),
        from: asString(json['from']),
        to: asString(json['to']),
      );

  JsonMap toJson() => {'key': key, 'label': label, 'from': from, 'to': to};
}

const List<String> _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Puntos de la evolución temporal: día → los últimos 14 días; mes → cada día;
/// año → cada mes.
List<TimeBucket> timeBuckets(FinancePeriodKind period, String anchor) {
  if (period == 'year') {
    final year = parseDateKey(anchor).year;
    return [
      for (var month = 0; month < _monthsShort.length; month++)
        () {
          final range = periodRange('month', toDateKey(DateTime(year, month + 1, 1)));
          return TimeBucket(key: range.from.substring(0, 7), label: _monthsShort[month], from: range.from, to: range.to);
        }(),
    ];
  }

  final range = period == 'month' ? periodRange('month', anchor) : PeriodRange(from: _addDays(anchor, -13), to: anchor);
  final buckets = <TimeBucket>[];

  for (var key = range.from; key.compareTo(range.to) <= 0; key = _addDays(key, 1)) {
    final date = parseDateKey(key);
    buckets.add(TimeBucket(key: key, label: '${date.day} ${_monthsShort[date.month - 1]}', from: key, to: key));
  }

  return buckets;
}

FinanceTotals emptyTotals() => const FinanceTotals(
      revenue: 0,
      costs: 0,
      foodCost: 0,
      laborCost: 0,
      operatingCost: 0,
      profit: 0,
      orders: 0,
      guests: 0,
      days: 0,
      expenses: OperatingExpenses.zero,
      byMethod: RevenueByMethod.zero,
    );

FinanceTotals sumTotals(List<DailyFinancial> rows) {
  var revenue = 0.0;
  var costs = 0.0;
  var foodCost = 0.0;
  var laborCost = 0.0;
  var operatingCost = 0.0;
  var profit = 0.0;
  var orders = 0;
  var guests = 0;
  var expenses = OperatingExpenses.zero;
  var byMethod = RevenueByMethod.zero;

  for (final row in rows) {
    revenue += row.revenue;
    foodCost += row.foodCost;
    laborCost += row.laborCost;
    operatingCost += row.operatingCost;
    costs += row.foodCost + row.laborCost + row.operatingCost;
    profit += row.profit;
    orders += row.orders;
    guests += row.guests;
    expenses += row.expenses;
    byMethod += row.byMethod;
  }

  return FinanceTotals(
    revenue: revenue,
    costs: costs,
    foodCost: foodCost,
    laborCost: laborCost,
    operatingCost: operatingCost,
    profit: profit,
    orders: orders,
    guests: guests,
    days: rows.length,
    expenses: expenses,
    byMethod: byMethod,
  );
}

/// Etiqueta legible del período: "domingo, 11 de octubre de 2026", "octubre de 2026", "2026".
String periodLabel(FinancePeriodKind period, String anchor) {
  final date = parseDateKey(anchor);

  if (period == 'day') {
    return DateFormat("EEEE, d 'de' MMMM 'de' y", 'es').format(date);
  }

  if (period == 'month') {
    return DateFormat("MMMM 'de' y", 'es').format(date);
  }

  return '${date.year}';
}

String comparisonLabel(FinancePeriodKind period) =>
    const {'day': 'vs. mismo día semana anterior', 'month': 'vs. mes anterior', 'year': 'vs. año anterior'}[period] ?? '';
