import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuración del entorno. La URL del API se puede fijar al compilar:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
class AppConfig {
  AppConfig._();

  static const String _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  static const String _apiEnvironment = String.fromEnvironment('API_ENV', defaultValue: 'production');
  static const String _productionUrl =
      'https://restaurant-api-demo-huf9eucheyg3a9de.westus2-01.azurewebsites.net';

  /// Azure es el destino por defecto. En modo local, Android emulado usa
  /// 10.0.2.2 y las demás plataformas usan localhost.
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
