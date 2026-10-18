import 'dart:math';

import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Instante en la zona horaria IANA de la sede (Europe/Madrid, America/Lima…).
/// Sin zona (o desconocida), la hora local del dispositivo.
DateTime inZone(DateTime instant, [String? timeZone]) {
  if (timeZone == null || timeZone.isEmpty) {
    return instant.toLocal();
  }

  try {
    return tz.TZDateTime.from(instant, tz.getLocation(timeZone));
  } catch (_) {
    return instant.toLocal();
  }
}

DateTime parseIso(String isoDate) => DateTime.tryParse(isoDate) ?? DateTime.fromMillisecondsSinceEpoch(0);

int nowMs() => DateTime.now().millisecondsSinceEpoch;

int minutesSince(String isoDate, [int? now]) {
  final diff = (now ?? nowMs()) - parseIso(isoDate).millisecondsSinceEpoch;
  return max((diff / 60000).floor(), 0);
}

String formatElapsed(String isoDate, [int? now]) {
  final minutes = minutesSince(isoDate, now);

  if (minutes < 1) {
    return 'recién';
  }

  if (minutes < 60) {
    return 'hace $minutes min';
  }

  final hours = minutes ~/ 60;

  if (hours < 24) {
    return 'hace $hours h ${minutes % 60} min';
  }

  // Más de un día: días y horas, sin minutos.
  final days = hours ~/ 24;
  return hours % 24 != 0 ? 'hace $days d ${hours % 24} h' : 'hace $days d';
}

String formatTime(String isoDate, [String? timeZone]) => DateFormat('HH:mm', 'es').format(inZone(parseIso(isoDate), timeZone));

String formatDateTime(String isoDate, [String? timeZone]) =>
    DateFormat('d/M/yy HH:mm', 'es').format(inZone(parseIso(isoDate), timeZone));

/// "2026-09-20T18:30:00Z" → "septiembre de 2026". Para fechas de alta ("miembro desde").
String formatMonthYear(String isoDate) => DateFormat("MMMM 'de' y", 'es').format(parseIso(isoDate).toLocal());

/// Fecha local (YYYY-MM-DD) de un instante en la zona horaria de la sede.
String localDateKey(String isoDate, [String? timeZone]) => DateFormat('yyyy-MM-dd').format(inZone(parseIso(isoDate), timeZone));

String nowIso() => DateTime.now().toUtc().toIso8601String();

final Random _random = Random.secure();

/// `createId('att')` → "att-3f9a1c0b2e7d". Mismo formato que el front web.
String createId(String prefix) {
  const hex = '0123456789abcdef';
  final suffix = List.generate(12, (_) => hex[_random.nextInt(16)]).join();
  return '$prefix-$suffix';
}
