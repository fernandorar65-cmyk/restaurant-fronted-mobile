import 'dart:convert';

import 'package:http/http.dart' as http_pkg;

import '../../modules/auth/storage.dart';
import '../config/env.dart';
import '../storage/local_storage.dart';

class HttpError implements Exception {
  HttpError(this.message, this.status);

  final String message;
  final int status;

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

/// Petición al API. Devuelve el JSON ya decodificado (`Map`, `List`, valor o null).
/// Si el backend envuelve la respuesta en `ApiResponse`, devuelve solo `data`.
///
/// ```dart
/// final users = await http('/users?email=a@b.com');
/// await http('/users/1', method: 'PATCH', body: {'name': 'Ana'});
/// ```
Future<dynamic> http(String path, {String method = 'GET', Object? body, Map<String, String>? headers}) async {
  final requestHeaders = <String, String>{'Accept': 'application/json', ...?headers};

  if (body != null && !requestHeaders.containsKey('Content-Type')) {
    requestHeaders['Content-Type'] = 'application/json';
  }

  final accessToken = LocalStorage.getItem(accessTokenKey);

  if (accessToken != null && !requestHeaders.containsKey('Authorization')) {
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
    throw HttpError(getApiErrorMessage(payload, 'La petición a $path falló'), response.statusCode);
  }

  if (response.statusCode == 204) {
    return null;
  }

  if (isApiResponse(payload)) {
    return (payload as Map)['data'];
  }

  return payload;
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

/// json-server recarga db.json cada vez que termina de escribir y puede descartar un cambio
/// que llega justo en ese momento (aunque responda 200). Cuando una acción hace varias
/// escrituras seguidas, se espera este margen entre una y otra.
/// Con el backend real cada acción será una sola petición y esto desaparece.
const int jsonServerWriteGapMs = 400;

Future<void> waitForJsonServer() => Future<void>.delayed(const Duration(milliseconds: jsonServerWriteGapMs));
