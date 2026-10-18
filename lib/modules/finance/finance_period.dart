import 'package:flutter/foundation.dart';

import 'period.dart';
import 'types.dart';

/// Valor de cada período en la query de la URL (?periodo=mes&fecha=2026-10-11).
const Map<FinancePeriodKind, String> financePeriodQuery = {'day': 'dia', 'month': 'mes', 'year': 'anio'};

final RegExp _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Período y fecha de Finanzas. En el front web viven en la URL para conservarse al pasar
/// del resumen al detalle de un local y al volver; aquí la vista recibe los valores de la
/// query en el constructor y, si quiere, escucha los cambios para reflejarlos en la ruta.
class FinancePeriod extends ChangeNotifier {
  /// `periodo` y `fecha` son los valores crudos de la query (`'mes'`, `'2026-10-11'`).
  FinancePeriod({String? periodo, String? fecha}) : today = toDateKey(DateTime.now()) {
    _period = financePeriodQuery.entries.where((entry) => entry.value == periodo).firstOrNull?.key ?? 'month';
    final queryDate = fecha != null && _dateKeyPattern.hasMatch(fecha) ? fecha : null;
    _anchor = queryDate != null && queryDate.compareTo(today) <= 0 ? queryDate : today;
  }

  final String today;

  late FinancePeriodKind _period;
  late String _anchor;

  FinancePeriodKind get period => _period;

  set period(FinancePeriodKind value) {
    if (value == _period) return;
    _period = value;
    notifyListeners();
  }

  String get anchor => _anchor;

  set anchor(String value) {
    if (value == _anchor) return;
    _anchor = value;
    notifyListeners();
  }

  /// Query para enlazar a otra vista de Finanzas con el mismo período.
  Map<String, String> periodQuery() => {'periodo': financePeriodQuery[_period] ?? 'mes', 'fecha': _anchor};
}
