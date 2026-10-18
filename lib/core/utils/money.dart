import 'package:intl/intl.dart';

final Map<String, NumberFormat> _formatters = {};

NumberFormat _formatterFor(String currency) {
  return _formatters.putIfAbsent(currency, () {
    try {
      return NumberFormat.simpleCurrency(locale: 'es', name: currency);
    } catch (_) {
      return NumberFormat.simpleCurrency(locale: 'es', name: 'EUR');
    }
  });
}

String formatMoney(num amount, [String currency = 'EUR']) => _formatterFor(currency).format(amount);

double roundMoney(num amount) => (amount * 100).roundToDouble() / 100;

const double moneyEpsilon = 0.001;
