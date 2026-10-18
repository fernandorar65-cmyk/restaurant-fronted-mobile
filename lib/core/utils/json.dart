/// Lectura tolerante de JSON (equivalente a los type guards del front web).
/// json-server puede devolver ids numéricos o de texto y campos faltantes.
library;

typedef JsonMap = Map<String, dynamic>;

JsonMap asMap(Object? value) => value is Map ? value.map((key, item) => MapEntry('$key', item)) : <String, dynamic>{};

JsonMap? asMapOrNull(Object? value) => value is Map ? asMap(value) : null;

List<dynamic> asList(Object? value) => value is List ? value : const [];

/// Lista de mapas: descarta lo que no sea objeto.
List<JsonMap> asMapList(Object? value) => asList(value).whereType<Map>().map(asMap).toList();

String asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return fallback;
}

String? asStringOrNull(Object? value) {
  if (value is String) return value;
  if (value is num) return '$value';
  return null;
}

/// Id como texto (json-server a veces guarda números).
String asId(Object? value) => asString(value);

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round() ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value == 'true';
  if (value is num) return value != 0;
  return fallback;
}

List<String> asStringList(Object? value) => asList(value).where((item) => item is String || item is num).map((item) => '$item').toList();

/// Codifica un parámetro de query (equivalente a `encodeURIComponent`).
String encodeQuery(String value) => Uri.encodeQueryComponent(value);
