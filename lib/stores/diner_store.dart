import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/http/http_client.dart';
import '../core/storage/local_storage.dart';
import '../core/utils/json.dart';
import '../core/utils/time.dart';

const String _dinerKey = 'restaurant-cmr:diner';
const String _recentKey = 'restaurant-cmr:recent-restaurants';
const int _recentLimit = 6;

/// Código de la mesa donde está el comensal. Hoy se ingresa a mano al ir a pagar;
/// el flujo del QR lo guarda al abrir la mesa.
const String _tableCodeKey = 'restaurant-cmr:table-code';

class DinerCustomer {
  const DinerCustomer({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory DinerCustomer.fromJson(JsonMap json) =>
      DinerCustomer(id: asId(json['id']), name: asString(json['name']), email: asString(json['email']));

  JsonMap toJson() => {'id': id, 'name': name, 'email': email};
}

/// Sede que el comensal abrió hace poco (por QR o desde el mapa).
class RecentRestaurant {
  const RecentRestaurant({required this.id, required this.visitedAt});

  final String id;
  final String visitedAt;

  JsonMap toJson() => {'id': id, 'visitedAt': visitedAt};
}

/// Identificador de mesa (texto libre) asociado a la sede donde se guardó.
class StoredTableCode {
  const StoredTableCode({required this.restaurantId, required this.code, required this.savedAt});

  final String restaurantId;
  final String code;
  final String savedAt;

  JsonMap toJson() => {'restaurantId': restaurantId, 'code': code, 'savedAt': savedAt};
}

/// Cómo entró el comensal: 'qr' (escaneando el QR de una mesa) o 'manual' (eligiendo la sede).
typedef DinerEntry = String;

/// Ruta de la app (path) para navegar con `context.go(...)`.
typedef AppPath = String;

/// Contexto del comensal (sede, mesa, atención en curso y cuenta opcional).
/// Se guarda para sobrevivir a cerrar la app.
class DinerStore extends ChangeNotifier {
  DinerStore() {
    final stored = asMap(LocalStorage.readJson(_dinerKey));
    restaurantId = asStringOrNull(stored['restaurantId']);
    restaurantSlug = asStringOrNull(stored['restaurantSlug']);
    restaurantName = asStringOrNull(stored['restaurantName']);
    currency = asString(stored['currency'], 'EUR');
    tableNumber = asStringOrNull(stored['tableNumber']);
    entry = asStringOrNull(stored['entry']);
    confirmed = asBool(stored['confirmed']);
    attentionId = asStringOrNull(stored['attentionId']);
    final customerJson = asMapOrNull(stored['customer']);
    _customerAccess = asStringOrNull(stored['customerAccess']);
    _customerRefresh = asStringOrNull(stored['customerRefresh']);
    customer = customerJson == null || _customerAccess == null || _customerRefresh == null
        ? null
        : DinerCustomer.fromJson(customerJson);

    recentRestaurants = asMapList(LocalStorage.readJson(_recentKey))
        .where((item) => item['id'] is String && item['visitedAt'] is String)
        .map((item) => RecentRestaurant(id: item['id'] as String, visitedAt: item['visitedAt'] as String))
        .toList();

    final code = asMapOrNull(LocalStorage.readJson(_tableCodeKey));
    if (code != null && code['restaurantId'] is String && asString(code['code']).trim().isNotEmpty) {
      _storedTableCode = StoredTableCode(
        restaurantId: code['restaurantId'] as String,
        code: asString(code['code']),
        savedAt: asString(code['savedAt']),
      );
    }
  }

  String? restaurantId;
  String? restaurantSlug;
  String? restaurantName;
  String currency = 'EUR';
  String? tableNumber;
  DinerEntry? entry;

  /// El comensal confirmó que está en esa mesa y eligió invitado o cuenta.
  bool confirmed = false;
  String? attentionId;
  DinerCustomer? customer;
  String? _customerAccess;
  String? _customerRefresh;
  int _customerSession = 0;
  Future<void>? _customerRenewal;
  List<RecentRestaurant> recentRestaurants = [];
  StoredTableCode? _storedTableCode;

  /// Código de mesa válido solo para la sede actual: uno de otra sede no sirve para pagar aquí.
  String? get tableCode =>
      _storedTableCode != null && _storedTableCode!.restaurantId == restaurantId ? _storedTableCode!.code : null;

  bool get hasRestaurant => restaurantId != null;

  bool get hasTable => tableNumber != null;

  bool get isReadyToOrder => hasRestaurant && hasTable && confirmed;

  /// Carta de la sede actual; sin sede (o sin slug guardado), el inicio para elegir una.
  AppPath get menuRoute => restaurantSlug != null ? '/$restaurantSlug/menu' : '/';

  /// La sede pasa al inicio de los recientes, sin duplicados.
  void rememberRestaurant(String id) {
    recentRestaurants = [
      RecentRestaurant(id: id, visitedAt: nowIso()),
      ...recentRestaurants.where((item) => item.id != id),
    ].take(_recentLimit).toList();
    LocalStorage.writeJson(_recentKey, recentRestaurants.map((item) => item.toJson()).toList());
    notifyListeners();
  }

  void setTableCode(String forRestaurantId, String code) {
    _storedTableCode = StoredTableCode(restaurantId: forRestaurantId, code: code.trim(), savedAt: nowIso());
    LocalStorage.writeJson(_tableCodeKey, _storedTableCode!.toJson());
    notifyListeners();
  }

  void clearTableCode() {
    _storedTableCode = null;
    LocalStorage.removeItem(_tableCodeKey);
    notifyListeners();
  }

  /// Fija sede y mesa. Si cambia la mesa o la sede, se olvida la atención anterior.
  void setTable({
    required String restaurantId,
    required String restaurantSlug,
    required String restaurantName,
    required String currency,
    required String tableNumber,
    required DinerEntry entry,
  }) {
    final changed = this.restaurantId != restaurantId || this.tableNumber != tableNumber;

    this.restaurantId = restaurantId;
    this.restaurantSlug = restaurantSlug;
    this.restaurantName = restaurantName;
    this.currency = currency;
    this.tableNumber = tableNumber;
    this.entry = entry;
    rememberRestaurant(restaurantId);
    // La mesa que llega por QR también queda como código de mesa para el pago.
    setTableCode(restaurantId, tableNumber);

    if (changed) {
      confirmed = false;
      attentionId = null;
    }

    _save();
  }

  /// Consultar la carta de una sede sin mesa (no permite pedir).
  void browse({required String restaurantId, required String restaurantSlug, required String restaurantName, required String currency}) {
    this.restaurantId = restaurantId;
    this.restaurantSlug = restaurantSlug;
    this.restaurantName = restaurantName;
    this.currency = currency;
    tableNumber = null;
    entry = 'manual';
    confirmed = false;
    attentionId = null;
    rememberRestaurant(restaurantId);
    _save();
  }

  void confirmTable() {
    confirmed = true;
    _save();
  }

  void setAttention(String? id) {
    attentionId = id;
    _save();
  }

  void startCustomerSession(DinerCustomer next, {required String accessToken, required String refreshToken}) {
    _customerSession++;
    _customerRenewal = null;
    _customerAccess = accessToken;
    _customerRefresh = refreshToken;
    customer = next;
    _save();
  }

  void setCustomer(DinerCustomer? next) {
    if (next == null) {
      final access = _customerAccess;
      final refresh = _customerRefresh;
      _clearCustomer();
      if (access != null && refresh != null) {
        unawaited(_revokeCustomer(access, refresh));
      }
      return;
    }
    if (customer?.id != next.id) return;
    customer = next;
    _save();
  }

  void _clearCustomer() {
    _customerSession++;
    _customerRenewal = null;
    _customerAccess = null;
    _customerRefresh = null;
    customer = null;
    _save();
  }

  Future<void> _revokeCustomer(String access, String refresh) async {
    try {
      await http('/api/v1/customer/auth/logout', method: 'POST', authenticated: false,
        headers: {'Authorization': 'Bearer $access'}, body: {'refreshToken': refresh});
    } on HttpError {
      // El cierre local ya se completó.
    }
  }

  Future<dynamic> customerRequest(String path, {String method = 'GET', Object? body}) async {
    final access = _customerAccess;
    final refresh = _customerRefresh;
    final session = _customerSession;
    if (access == null || refresh == null) throw HttpError('Inicia sesión para continuar', 401);

    Future<dynamic> send(String token) => http(path, method: method, body: body, authenticated: false,
      headers: {'Authorization': 'Bearer $token'});

    try {
      final result = await send(access);
      if (_customerSession != session) throw HttpError('La sesión cambió', 401);
      return result;
    } on HttpError catch (error) {
      if (_customerSession != session) rethrow;
      if (error.errorCode == 'ACCOUNT_DISABLED') _clearCustomer();
      if (error.status != 401 || error.errorCode != 'INVALID_ACCESS_TOKEN') rethrow;
      if (_customerAccess == access) {
        await (_customerRenewal ??= _renewCustomer(session, refresh).whenComplete(() {
          if (_customerSession == session) _customerRenewal = null;
        }));
      }
      final renewed = _customerAccess;
      if (_customerSession != session || renewed == null) rethrow;
      final result = await send(renewed);
      if (_customerSession != session) throw HttpError('La sesión cambió', 401);
      return result;
    }
  }

  Future<void> _renewCustomer(int session, String refresh) async {
    try {
      final data = asMap(await http('/api/v1/customer/auth/refresh', method: 'POST',
        authenticated: false, body: {'refreshToken': refresh}));
      final access = asString(data['accessToken']);
      final rotated = asString(data['refreshToken']);
      if (access.isEmpty || rotated.isEmpty) throw HttpError('Respuesta de renovación inesperada', 500);
      if (_customerSession != session) {
        await _revokeCustomer(access, rotated);
        return;
      }
      _customerAccess = access;
      _customerRefresh = rotated;
      _save();
    } on HttpError catch (error) {
      if (_customerSession == session &&
          (error.errorCode == 'INVALID_REFRESH_TOKEN' || error.errorCode == 'ACCOUNT_DISABLED')) {
        _clearCustomer();
      }
      rethrow;
    }
  }

  void leaveTable() {
    restaurantId = null;
    restaurantSlug = null;
    restaurantName = null;
    tableNumber = null;
    entry = null;
    confirmed = false;
    attentionId = null;
    _save();
  }

  void _save() {
    LocalStorage.writeJson(_dinerKey, {
      'restaurantId': restaurantId,
      'restaurantSlug': restaurantSlug,
      'restaurantName': restaurantName,
      'currency': currency,
      'tableNumber': tableNumber,
      'entry': entry,
      'confirmed': confirmed,
      'attentionId': attentionId,
      'customer': customer?.toJson(),
      'customerAccess': _customerAccess,
      'customerRefresh': _customerRefresh,
    });
    notifyListeners();
  }
}
