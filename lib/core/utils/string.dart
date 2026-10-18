bool isNonEmptyString(String? value) => value != null && value.trim().isNotEmpty;

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

String _stripAccents(String value) => value.split('').map((char) => _accents[char] ?? char).join();

/// Minúsculas y sin tildes: "Jamón Ibérico" → "jamon iberico". Para comparar búsquedas.
String normalizeSearch(String value) => _stripAccents(value.toLowerCase()).trim();

/// "L'Étoile Atelier" → "l-etoile-atelier", para usar en URLs.
String slugify(String value) {
  return _stripAccents(value.toLowerCase())
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

  if (parts.isEmpty) {
    return '?';
  }

  final first = parts.first;
  final last = parts.length > 1 ? parts.last : null;

  if (last == null || last == first) {
    return (first.length > 2 ? first.substring(0, 2) : first).toUpperCase();
  }

  return '${first[0]}${last[0]}'.toUpperCase();
}
