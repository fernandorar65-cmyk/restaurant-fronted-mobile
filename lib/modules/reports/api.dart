import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/time.dart';
import 'metrics.dart';

class DailyClosingRecord {
  const DailyClosingRecord({
    required this.id,
    required this.restaurantId,
    required this.dateKey,
    required this.totalPaid,
    required this.closedAttentions,
    required this.cancelledAttentions,
    required this.openAttentions,
    required this.byMethod,
    this.closedBy,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String dateKey;
  final double totalPaid;
  final int closedAttentions;
  final int cancelledAttentions;
  final int openAttentions;
  final List<DailyClosingMethodTotal> byMethod;
  final String? closedBy;
  final String createdAt;

  /// Equivalente a `isClosing` + `toClosing`: null si faltan campos obligatorios.
  static DailyClosingRecord? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);

    if ((json['id'] is! String && json['id'] is! num) ||
        (json['restaurantId'] is! String && json['restaurantId'] is! num) ||
        json['dateKey'] is! String ||
        json['totalPaid'] is! num ||
        json['createdAt'] is! String) {
      return null;
    }

    return DailyClosingRecord.fromJson(json);
  }

  factory DailyClosingRecord.fromJson(JsonMap json) => DailyClosingRecord(
        id: asId(json['id']),
        restaurantId: asId(json['restaurantId']),
        dateKey: asString(json['dateKey']),
        totalPaid: asDouble(json['totalPaid']),
        closedAttentions: asInt(json['closedAttentions']),
        cancelledAttentions: asInt(json['cancelledAttentions']),
        openAttentions: asInt(json['openAttentions']),
        byMethod: asMapList(json['byMethod']).map(DailyClosingMethodTotal.fromJson).toList(),
        closedBy: asStringOrNull(json['closedBy']),
        createdAt: asString(json['createdAt']),
      );

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'dateKey': dateKey,
        'totalPaid': totalPaid,
        'closedAttentions': closedAttentions,
        'cancelledAttentions': cancelledAttentions,
        'openAttentions': openAttentions,
        'byMethod': byMethod.map((entry) => entry.toJson()).toList(),
        'closedBy': closedBy,
        'createdAt': createdAt,
      };
}

Future<List<DailyClosingRecord>> fetchDailyClosings(String restaurantId) async {
  final payload = await http('/dailyClosures');

  if (payload is! List) {
    return [];
  }

  return payload
      .map(DailyClosingRecord.tryParse)
      .whereType<DailyClosingRecord>()
      .where((closing) => closing.restaurantId == restaurantId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Guarda el cierre del día. Si ya existía uno para esa fecha, lo reemplaza.
Future<DailyClosingRecord> saveDailyClosing(String restaurantId, DailyClosingSummary summary, String? closedBy) async {
  final existing = (await fetchDailyClosings(restaurantId)).where((closing) => closing.dateKey == summary.dateKey).firstOrNull;
  final body = {
    'restaurantId': restaurantId,
    'dateKey': summary.dateKey,
    'totalPaid': summary.totalPaid,
    'closedAttentions': summary.closed,
    'cancelledAttentions': summary.cancelled,
    'openAttentions': summary.open,
    'byMethod': summary.byMethod.map((entry) => entry.toJson()).toList(),
    'closedBy': closedBy,
    'createdAt': nowIso(),
  };

  final payload = existing != null
      ? await http('/dailyClosures/${existing.id}', method: 'PUT', body: body)
      : await http('/dailyClosures', method: 'POST', body: body);

  final closing = DailyClosingRecord.tryParse(payload);

  if (closing == null) {
    throw HttpError('No se pudo guardar el cierre.', 500);
  }

  return closing;
}
