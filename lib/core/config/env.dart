import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuración del entorno. La URL del API se puede fijar al compilar:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
class AppConfig {
  AppConfig._();

  static const String _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  static const String _apiEnvironment = String.fromEnvironment('API_ENV', defaultValue: 'local');
  static const String _productionUrl =
      'https://restaurant-api-demo-huf9eucheyg3a9de.westus2-01.azurewebsites.net';

  /// Sin `API_BASE_URL`: el emulador de Android llega al localhost de la máquina por
  /// 10.0.2.2; el simulador de iOS, la web y el escritorio usan localhost directamente.
  static String get apiBaseUrl {
    if (_fromEnvironment.isNotEmpty) {
      return _fromEnvironment.replaceFirst(RegExp(r'/+$'), '');
    }

    switch (_apiEnvironment) {
      case 'production':
        return _productionUrl;
      case 'local':
        break;
      default:
        throw ArgumentError.value(_apiEnvironment, 'API_ENV', 'Usa local o production');
    }

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://localhost:3000';
  }

  /// Origen público del front web: con él se arman los enlaces de los QR de mesa.
  /// `flutter run --dart-define=PUBLIC_WEB_URL=https://mi-dominio`
  static const String publicWebUrl = String.fromEnvironment('PUBLIC_WEB_URL', defaultValue: 'http://localhost:5173');

  static const String appName = 'Restaurant CMR';
}
