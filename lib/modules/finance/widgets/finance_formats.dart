import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Paleta categórica de los gráficos (`--series-1…8` de main.css): validada para
/// daltonismo; el modo oscuro tiene sus propios tonos.
const List<Color> _seriesLight = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
  Color(0xFF4A3AA7),
  Color(0xFFE34948),
];

const List<Color> _seriesDark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
  Color(0xFF9085E9),
  Color(0xFFE66767),
];

/// Color de la serie `n` (1 a 8, como `var(--series-n)`); se repite cada 8.
Color seriesColor(BuildContext context, int n) {
  final palette = Theme.of(context).brightness == Brightness.dark ? _seriesDark : _seriesLight;
  return palette[(n - 1) % palette.length];
}

const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

/// Formatos de Finanzas (equivalen a los `Intl.NumberFormat` de las vistas web).
class FinanceFormats {
  FinanceFormats(String currency)
      : _money = _currency(currency, compact: false),
        _compact = _currency(currency, compact: true);

  final NumberFormat _money;
  final NumberFormat _compact;
  static final NumberFormat _integer = NumberFormat.decimalPattern('es');
  static final NumberFormat _percent = NumberFormat.percentPattern('es')
    ..maximumFractionDigits = 1
    ..minimumFractionDigits = 0;

  static NumberFormat _currency(String currency, {required bool compact}) {
    NumberFormat build(String name) {
      final format = compact
          ? NumberFormat.compactSimpleCurrency(locale: 'es', name: name)
          : NumberFormat.simpleCurrency(locale: 'es', name: name, decimalDigits: 0);
      return format
        ..maximumFractionDigits = compact ? 1 : 0
        ..minimumFractionDigits = 0;
    }

    try {
      return build(currency);
    } catch (_) {
      return build('EUR');
    }
  }

  /// Moneda sin decimales: "12.340 €".
  String money(num value) => _money.format(value);

  /// Moneda abreviada para ejes: "12,3 mil €".
  String compact(num value) => _compact.format(value);

  static String integer(num value) => _integer.format(value);

  static String percent(num value) => _percent.format(value);

  /// Variación con signo: "+12,5 %".
  static String delta(num value) => '${value >= 0 ? '+' : ''}${_percent.format(value)}';
}

/// "domingo, 11 de octubre" → "Domingo, 11 de octubre".
String capitalizeFirst(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
