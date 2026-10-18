import 'package:flutter/material.dart';

import '../core/storage/local_storage.dart';

const String themeKey = 'restaurant-cmr:theme';

/// 'light' | 'dark' | 'system'
typedef ThemePreference = String;

/// Tema claro/oscuro de toda la app. "system" sigue la configuración del dispositivo
/// y cambia en vivo si el usuario la cambia.
class ThemeStore extends ChangeNotifier {
  ThemeStore() {
    final value = LocalStorage.getItem(themeKey);
    preference = value == 'light' || value == 'dark' ? value! : 'system';
  }

  late ThemePreference preference;

  ThemeMode get mode => switch (preference) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void setPreference(ThemePreference next) {
    preference = next;

    if (next == 'system') {
      LocalStorage.removeItem(themeKey);
    } else {
      LocalStorage.setItem(themeKey, next);
    }

    notifyListeners();
  }
}
