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
    refreshToken = LocalStorage.getItem(refreshTokenKey);
    persistSession = accessToken != null;
    final stored = LocalStorage.readJson(userKey);

    if (stored is Map && stored['id'] is String && stored['name'] is String && stored['email'] is String) {
      user = AuthUser.fromJson(asMap(stored));
    }

    _syncTokens();
    AuthTokens.onTokensChanged = _onTokensRefreshed;
    AuthTokens.onSessionExpired = clearAuth;
  }

  String? restaurantId;
  String? accessToken;
  String? refreshToken;
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

  /// El cliente HTTP lee los tokens de [AuthTokens] (también sin "Mantener sesión").
  void _syncTokens() {
    AuthTokens.accessToken = accessToken;
    AuthTokens.refreshToken = refreshToken;
  }

  void _storeTokens() {
    if (!persistSession) return;

    LocalStorage.setItem(accessTokenKey, accessToken!);
    if (refreshToken != null && refreshToken!.isNotEmpty) {
      LocalStorage.setItem(refreshTokenKey, refreshToken!);
    } else {
      LocalStorage.removeItem(refreshTokenKey);
    }
  }

  /// El cliente HTTP renovó el par: se guarda el último (el refresh es de un solo uso).
  void _onTokensRefreshed(String nextAccessToken, String nextRefreshToken) {
    accessToken = nextAccessToken;
    refreshToken = nextRefreshToken;
    _storeTokens();
  }

  void setSession(AuthSession session, {bool persist = true}) {
    accessToken = session.accessToken;
    refreshToken = session.refreshToken;
    persistSession = persist;
    user = session.user;
    _syncTokens();

    if (!persist) {
      LocalStorage.removeItem(accessTokenKey);
      LocalStorage.removeItem(refreshTokenKey);
      LocalStorage.removeItem(userKey);
    } else {
      _storeTokens();
      LocalStorage.writeJson(userKey, session.user.toJson());
    }

    notifyListeners();
  }

  /// Cierra la sesión local e invalida el refresh token en el backend (sin esperar).
  void clearAuth() {
    final previousRefreshToken = refreshToken;
    final previousAccessToken = accessToken;

    accessToken = null;
    refreshToken = null;
    user = null;
    restaurantId = null;
    _syncTokens();
    LocalStorage.removeItem(accessTokenKey);
    LocalStorage.removeItem(refreshTokenKey);
    LocalStorage.removeItem(userKey);
    notifyListeners();

    if (previousRefreshToken != null && previousRefreshToken.isNotEmpty) {
      logout(refreshToken: previousRefreshToken, accessToken: previousAccessToken);
    }
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
