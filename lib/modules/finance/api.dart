import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import 'types.dart';

/// Cierres diarios entre dos fechas (inclusive), de todas las sedes.
/// Contrato pensado para el backend: GET /finance/daily?from=…&to=…&restaurantIds=…
/// (allí se calculará desde las atenciones y pagos cerrados; hoy viene de db.json).
Future<List<DailyFinancial>> fetchDailyFinancials(String from, String to) async {
  final query = '${encodeQuery('date:gte')}=${encodeQuery(from)}&${encodeQuery('date:lte')}=${encodeQuery(to)}';
  final payload = await http('/dailyFinancials?$query');

  if (payload is! List) {
    return [];
  }

  return payload.map(DailyFinancial.tryParse).whereType<DailyFinancial>().toList();
}
