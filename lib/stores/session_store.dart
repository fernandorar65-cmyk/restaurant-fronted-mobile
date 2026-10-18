import 'package:flutter/foundation.dart';

import '../core/storage/local_storage.dart';
import '../core/utils/json.dart';
import '../modules/auth/api.dart';
import '../modules/auth/permissions.dart';
import '../modules/auth/storage.dart';
import '../modules/auth/types.dart';

/// Sesión del personal del restaurante (lado de gestión). El contexto del comensal vive en `DinerStore`.
class SessionStore extends ChangeNotifier {
  SessionStore() {
    accessToken = LocalStorage.getItem(accessTokenKey);
    persistSession = accessToken != null;
    final stored = LocalStorage.readJson(userKey);

    if (stored is Map && stored['id'] is String && stored['name'] is String && stored['email'] is String) {
      user = AuthUser.fromJson(asMap(stored));
    }
  }

  String? restaurantId;
  String? accessToken;
  AuthUser? user;
  bool persistSession = false;

  bool get hasRestaurantContext => restaurantId != null;

  bool get isAuthenticated => accessToken != null && user != null;

  List<Permission> get permissions => user?.permissions ?? const [];

  bool get hasSiteAccess => permissions.any(sitePermissions.contains);

  bool get hasAdminAccess => permissions.any(adminPermissions.contains);

  bool can(Permission permission) => permissions.contains(permission);

  bool canAccessRestaurant(String id) {
    final allowed = user?.restaurantIds ?? const [];
    return allowed.isEmpty || allowed.contains(id);
  }

  void setRestaurant(String nextRestaurantId) {
    if (restaurantId == nextRestaurantId) return;
    restaurantId = nextRestaurantId;
    notifyListeners();
  }

  void _storeUser(AuthUser nextUser) {
    user = nextUser;

    if (persistSession) {
      LocalStorage.writeJson(userKey, nextUser.toJson());
    }

    notifyListeners();
  }

  void setSession(AuthSession session, {bool persist = true}) {
    accessToken = session.accessToken;
    persistSession = persist;
    user = session.user;

    if (!persist) {
      LocalStorage.removeItem(accessTokenKey);
      LocalStorage.removeItem(userKey);
    } else {
      LocalStorage.setItem(accessTokenKey, session.accessToken);
      LocalStorage.writeJson(userKey, session.user.toJson());
    }

    notifyListeners();
  }

  void clearAuth() {
    accessToken = null;
    user = null;
    restaurantId = null;
    LocalStorage.removeItem(accessTokenKey);
    LocalStorage.removeItem(userKey);
    notifyListeners();
  }

  /// Relee usuario y rol desde el API. Devuelve false si la cuenta fue bloqueada,
  /// desactivada o eliminada (y cierra la sesión).
  Future<bool> refreshUser() async {
    final current = user;

    if (current == null) {
      return false;
    }

    final fresh = await refreshAuthUser(current.id);

    if (fresh == null) {
      clearAuth();
      return false;
    }

    _storeUser(fresh);
    return true;
  }
}
