import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Equivalente a `localStorage` del front web: lectura síncrona sobre SharedPreferences
/// cargado al arrancar (ver `main.dart`).
class LocalStorage {
  LocalStorage._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getItem(String key) {
    try {
      return _prefs?.getString(key);
    } catch (_) {
      return null;
    }
  }

  static void setItem(String key, String value) {
    _prefs?.setString(key, value);
  }

  static void removeItem(String key) {
    _prefs?.remove(key);
  }

  /// Lee y decodifica JSON; devuelve null si no existe o está dañado.
  static Object? readJson(String key) {
    final raw = getItem(key);

    if (raw == null) {
      return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      removeItem(key);
      return null;
    }
  }

  static void writeJson(String key, Object? value) {
    try {
      setItem(key, jsonEncode(value));
    } catch (_) {
      // Sin almacenamiento: el dato vive solo en memoria.
    }
  }
}
