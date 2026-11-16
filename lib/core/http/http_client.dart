import 'dart:convert';

import 'package:http/http.dart' as http_pkg;

import '../../modules/auth/storage.dart';
import '../config/env.dart';

class HttpError implements Exception {
  HttpError(this.message, this.status, {this.errorCode});

  final String message;
  final int status;

  /// Código del backend (`INVALID_CREDENTIALS`, `ACCOUNT_DISABLED`…), si lo envía.
  final String? errorCode;

  @override
  String toString() => message;
}

/// Respuesta envuelta del backend NestJS (`{ success, data, message, ... }`).
bool isApiResponse(Object? value) => value is Map && value['success'] is bool && value.containsKey('data');

String getApiErrorMessage(Object? payload, String fallback) {
  if (payload is! Map) {
    return fallback;
  }

  final message = payload['message'];

  if (message is String && message.trim().isNotEmpty) {
    return message;
  }

  if (message is List && message.isNotEmpty && message.first is String) {
    return message.first as String;
  }

  return fallback;
}

final http_pkg.Client _client = http_pkg.Client();

/// Ruta del backend que renueva el par de tokens del personal.
const String ownerRefreshPath = '/api/v1/owner/auth/refresh';

/// Petición al API. Devuelve el JSON ya decodificado (`Map`, `List`, valor o null).
/// Si el backend envuelve la respuesta en `ApiResponse`, devuelve solo `data`.
/// Ante `401 INVALID_ACCESS_TOKEN` renueva los tokens una vez y reintenta.
///
/// ```dart
/// final users = await http('/users?email=a@b.com');
/// await http('/users/1', method: 'PATCH', body: {'name': 'Ana'});
/// ```
Future<dynamic> http(String path, {String method = 'GET', Object? body, Map<String, String>? headers, bool authenticated = true}) async {
  final sentToken = AuthTokens.accessToken;

  try {
    return await _send(path, method: method, body: body, headers: headers, authenticated: authenticated);
  } on HttpError catch (error) {
    final canRefresh = authenticated &&
        error.status == 401 &&
        error.errorCode == 'INVALID_ACCESS_TOKEN' &&
        sentToken != null &&
        !(headers?.containsKey('Authorization') ?? false);

    if (!canRefresh || !await _refreshTokens(sentToken)) {
      rethrow;
    }

    return _send(path, method: method, body: body, headers: headers);
  }
}

Future<dynamic> _send(String path, {required String method, Object? body, Map<String, String>? headers, bool authenticated = true}) async {
  final requestHeaders = <String, String>{'Accept': 'application/json', ...?headers};

  if (body != null && !requestHeaders.containsKey('Content-Type')) {
    requestHeaders['Content-Type'] = 'application/json';
  }

  final accessToken = AuthTokens.accessToken;

  if (authenticated && accessToken != null && !requestHeaders.containsKey('Authorization')) {
    requestHeaders['Authorization'] = 'Bearer $accessToken';
  }

  final request = http_pkg.Request(method, Uri.parse('${AppConfig.apiBaseUrl}$path'))..headers.addAll(requestHeaders);

  if (body != null) {
    request.body = jsonEncode(body);
  }

  final http_pkg.Response response;

  try {
    response = await http_pkg.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 20)));
  } catch (_) {
    throw HttpError('No pudimos conectarnos con el servidor', 0);
  }

  final payload = _readPayload(response);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorCode = payload is Map && payload['errorCode'] is String ? payload['errorCode'] as String : null;
    throw HttpError(getApiErrorMessage(payload, 'La petición a $path falló'), response.statusCode, errorCode: errorCode);
  }

  if (response.statusCode == 204) {
    return null;
  }

  if (isApiResponse(payload)) {
    return (payload as Map)['data'];
  }

  return payload;
}

/// Renovación en curso: si varias peticiones vencen a la vez, todas esperan la misma
/// (el refresh token es de un solo uso).
Future<bool>? _refreshing;

/// Renueva el par de tokens. Si otra petición ya lo renovó desde que se envió
/// [staleAccessToken], no hace falta pedirlo otra vez.
Future<bool> _refreshTokens(String staleAccessToken) {
  if (AuthTokens.accessToken != null && AuthTokens.accessToken != staleAccessToken) {
    return Future.value(true);
  }

  return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
}

Future<bool> _doRefresh() async {
  final refreshToken = AuthTokens.refreshToken;

  if (refreshToken == null) {
    AuthTokens.onSessionExpired?.call();
    return false;
  }

  try {
    final data = await _send(ownerRefreshPath, method: 'POST', body: {'refreshToken': refreshToken}, authenticated: false);

    if (data is! Map || data['accessToken'] is! String || data['refreshToken'] is! String) {
      AuthTokens.onSessionExpired?.call();
      return false;
    }

    final nextAccess = data['accessToken'] as String;
    final nextRefresh = data['refreshToken'] as String;
    AuthTokens.accessToken = nextAccess;
    AuthTokens.refreshToken = nextRefresh;
    AuthTokens.onTokensChanged?.call(nextAccess, nextRefresh);
    return true;
  } on HttpError catch (error) {
    // Sin conexión se mantiene la sesión; un refresh rechazado la cierra.
    if (error.status != 0) {
      AuthTokens.onSessionExpired?.call();
    }

    return false;
  }
}

Object? _readPayload(http_pkg.Response response) {
  final contentType = response.headers['content-type'] ?? '';

  if (response.statusCode == 204 || !contentType.contains('application/json')) {
    return null;
  }

  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } catch (_) {
    return null;
  }
}

/// Filtro exacto de json-server: `http('/attentions?${whereQuery({'restaurantId': id})}')`.
/// Con `?campo=valor` json-server convierte "1" en número y no coincide con los ids de texto;
/// `_where` respeta el tipo. Una lista filtra con `in` y un mapa pasa operadores tal cual
/// (`{'date': {'gte': from, 'lte': to}}`). Ignora los demás parámetros de la URL, así que
/// todo el filtro va aquí. Con el backend real cada consulta tendrá su endpoint.
String whereQuery(Map<String, Object> fields) {
  final where = {
    for (final MapEntry(:key, :value) in fields.entries)
      key: switch (value) {
        List() => {'in': value},
        Map() => value,
        _ => {'eq': value},
      },
  };
  return '_where=${Uri.encodeQueryComponent(jsonEncode(where))}';
}

/// json-server recarga db.json cada vez que termina de escribir y puede descartar un cambio
/// que llega justo en ese momento (aunque responda 200). Cuando una acción hace varias
/// escrituras seguidas, se espera este margen entre una y otra.
/// Con el backend real cada acción será una sola petición y esto desaparece.
const int jsonServerWriteGapMs = 400;

Future<void> waitForJsonServer() => Future<void>.delayed(const Duration(milliseconds: jsonServerWriteGapMs));
