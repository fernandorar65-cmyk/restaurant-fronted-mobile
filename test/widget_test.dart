import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_fronted_mobile/core/utils/string.dart';
import 'package:restaurant_fronted_mobile/core/utils/time.dart';

void main() {
  test('slugify quita tildes y símbolos', () {
    expect(slugify("L'Étoile Atelier"), 'l-etoile-atelier');
  });

  test('normalizeSearch compara sin tildes ni mayúsculas', () {
    expect(normalizeSearch('  Jamón Ibérico '), 'jamon iberico');
  });

  test('getInitials toma primera y última palabra', () {
    expect(getInitials('Ana María López'), 'AL');
    expect(getInitials('Ana'), 'AN');
    expect(getInitials(''), '?');
  });

  test('formatElapsed', () {
    final now = DateTime.utc(2026, 1, 1, 12).millisecondsSinceEpoch;
    expect(formatElapsed('2026-01-01T11:59:40Z', now), 'recién');
    expect(formatElapsed('2026-01-01T11:30:00Z', now), 'hace 30 min');
    expect(formatElapsed('2026-01-01T09:15:00Z', now), 'hace 2 h 45 min');
  });

  test('createId usa el prefijo y 12 caracteres hex', () {
    expect(RegExp(r'^att-[0-9a-f]{12}$').hasMatch(createId('att')), isTrue);
  });
}
