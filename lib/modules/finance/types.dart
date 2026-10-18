import '../../core/utils/json.dart';

double _number(JsonMap? json, String key, double fallback) {
  final raw = json?[key];
  // Si viene el objeto, lo que falte cuenta 0; si no viene, se usa el valor de respaldo.
  return raw is num ? raw.toDouble() : (json != null ? 0 : fallback);
}

/// Desglose del gasto de operación.
class OperatingExpenses {
  const OperatingExpenses({
    required this.rent,
    required this.utilities,
    required this.maintenance,
    required this.marketing,
    required this.other,
  });

  static const OperatingExpenses zero = OperatingExpenses(rent: 0, utilities: 0, maintenance: 0, marketing: 0, other: 0);

  /// Claves en el orden del front web.
  static const List<String> keys = ['rent', 'utilities', 'maintenance', 'marketing', 'other'];

  final double rent;
  final double utilities;
  final double maintenance;
  final double marketing;
  final double other;

  /// Equivalente a `toNumbers(value, keys, fallback)`: sin objeto, todo va a `fallbackOther`.
  factory OperatingExpenses.fromJson(Object? value, {double fallbackOther = 0}) {
    final json = asMapOrNull(value);
    return OperatingExpenses(
      rent: _number(json, 'rent', 0),
      utilities: _number(json, 'utilities', 0),
      maintenance: _number(json, 'maintenance', 0),
      marketing: _number(json, 'marketing', 0),
      other: _number(json, 'other', fallbackOther),
    );
  }

  /// Valor por clave (`expenses[key]` en TS).
  double operator [](String key) => switch (key) {
        'rent' => rent,
        'utilities' => utilities,
        'maintenance' => maintenance,
        'marketing' => marketing,
        'other' => other,
        _ => 0,
      };

  OperatingExpenses operator +(OperatingExpenses other) => OperatingExpenses(
        rent: rent + other.rent,
        utilities: utilities + other.utilities,
        maintenance: maintenance + other.maintenance,
        marketing: marketing + other.marketing,
        other: this.other + other.other,
      );

  JsonMap toJson() => {'rent': rent, 'utilities': utilities, 'maintenance': maintenance, 'marketing': marketing, 'other': other};
}

/// Ingresos por método de pago.
class RevenueByMethod {
  const RevenueByMethod({
    required this.card,
    required this.yape,
    required this.plin,
    required this.transfer,
    required this.cash,
  });

  static const RevenueByMethod zero = RevenueByMethod(card: 0, yape: 0, plin: 0, transfer: 0, cash: 0);

  /// Claves en el orden del front web.
  static const List<String> keys = ['card', 'yape', 'plin', 'transfer', 'cash'];

  final double card;
  final double yape;
  final double plin;
  final double transfer;
  final double cash;

  /// Equivalente a `toNumbers(value, keys, fallback)`: sin objeto, todo va a `fallbackCard`.
  factory RevenueByMethod.fromJson(Object? value, {double fallbackCard = 0}) {
    final json = asMapOrNull(value);
    return RevenueByMethod(
      card: _number(json, 'card', fallbackCard),
      yape: _number(json, 'yape', 0),
      plin: _number(json, 'plin', 0),
      transfer: _number(json, 'transfer', 0),
      cash: _number(json, 'cash', 0),
    );
  }

  double operator [](String key) => switch (key) {
        'card' => card,
        'yape' => yape,
        'plin' => plin,
        'transfer' => transfer,
        'cash' => cash,
        _ => 0,
      };

  RevenueByMethod operator +(RevenueByMethod other) => RevenueByMethod(
        card: card + other.card,
        yape: yape + other.yape,
        plin: plin + other.plin,
        transfer: transfer + other.transfer,
        cash: cash + other.cash,
      );

  JsonMap toJson() => {'card': card, 'yape': yape, 'plin': plin, 'transfer': transfer, 'cash': cash};
}

/// Cierre financiero de un día en una sede.
class DailyFinancial {
  const DailyFinancial({
    required this.id,
    required this.restaurantId,
    required this.date,
    required this.revenue,
    required this.orders,
    required this.guests,
    required this.foodCost,
    required this.laborCost,
    required this.operatingCost,
    required this.profit,
    required this.expenses,
    required this.byMethod,
  });

  final String id;
  final String restaurantId;

  /// YYYY-MM-DD
  final String date;
  final double revenue;
  final int orders;
  final int guests;
  final double foodCost;
  final double laborCost;
  final double operatingCost;

  /// Ingresos menos costos (insumos, personal y operación). Puede ser negativo.
  final double profit;
  final OperatingExpenses expenses;
  final RevenueByMethod byMethod;

  /// Equivalente a `isDailyFinancial`: null si faltan campos obligatorios.
  static DailyFinancial? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);

    if (json['id'] is! String ||
        (json['restaurantId'] is! String && json['restaurantId'] is! num) ||
        json['date'] is! String ||
        !['revenue', 'orders', 'foodCost', 'laborCost', 'operatingCost', 'profit'].every((key) => json[key] is num)) {
      return null;
    }

    return DailyFinancial.fromJson(json);
  }

  factory DailyFinancial.fromJson(JsonMap json) {
    final revenue = asDouble(json['revenue']);
    final operatingCost = asDouble(json['operatingCost']);

    return DailyFinancial(
      id: asId(json['id']),
      restaurantId: asId(json['restaurantId']),
      date: asString(json['date']),
      revenue: revenue,
      orders: asInt(json['orders']),
      guests: json['guests'] is num ? asInt(json['guests']) : 0,
      foodCost: asDouble(json['foodCost']),
      laborCost: asDouble(json['laborCost']),
      operatingCost: operatingCost,
      profit: asDouble(json['profit']),
      // Sin desglose guardado, todo el gasto de operación cuenta como "otros".
      expenses: OperatingExpenses.fromJson(json['expenses'], fallbackOther: operatingCost),
      byMethod: RevenueByMethod.fromJson(json['byMethod'], fallbackCard: revenue),
    );
  }

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'date': date,
        'revenue': revenue,
        'orders': orders,
        'guests': guests,
        'foodCost': foodCost,
        'laborCost': laborCost,
        'operatingCost': operatingCost,
        'profit': profit,
        'expenses': expenses.toJson(),
        'byMethod': byMethod.toJson(),
      };
}

/// 'day' | 'month' | 'year'. En TS se llama `FinancePeriod`; aquí cambia de nombre
/// para no chocar con el ChangeNotifier `FinancePeriod` (ver finance_period.dart).
typedef FinancePeriodKind = String;

const List<FinancePeriodKind> financePeriods = ['day', 'month', 'year'];

/// Totales de un conjunto de días.
class FinanceTotals {
  const FinanceTotals({
    required this.revenue,
    required this.costs,
    required this.foodCost,
    required this.laborCost,
    required this.operatingCost,
    required this.profit,
    required this.orders,
    required this.guests,
    required this.days,
    required this.expenses,
    required this.byMethod,
  });

  final double revenue;
  final double costs;
  final double foodCost;
  final double laborCost;
  final double operatingCost;
  final double profit;
  final int orders;
  final int guests;
  final int days;
  final OperatingExpenses expenses;
  final RevenueByMethod byMethod;

  factory FinanceTotals.fromJson(JsonMap json) => FinanceTotals(
        revenue: asDouble(json['revenue']),
        costs: asDouble(json['costs']),
        foodCost: asDouble(json['foodCost']),
        laborCost: asDouble(json['laborCost']),
        operatingCost: asDouble(json['operatingCost']),
        profit: asDouble(json['profit']),
        orders: asInt(json['orders']),
        guests: asInt(json['guests']),
        days: asInt(json['days']),
        expenses: OperatingExpenses.fromJson(json['expenses']),
        byMethod: RevenueByMethod.fromJson(json['byMethod']),
      );

  JsonMap toJson() => {
        'revenue': revenue,
        'costs': costs,
        'foodCost': foodCost,
        'laborCost': laborCost,
        'operatingCost': operatingCost,
        'profit': profit,
        'orders': orders,
        'guests': guests,
        'days': days,
        'expenses': expenses.toJson(),
        'byMethod': byMethod.toJson(),
      };
}
