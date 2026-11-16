const String accessTokenKey = 'restaurant-cmr.accessToken';
const String refreshTokenKey = 'restaurant-cmr.refreshToken';
const String userKey = 'restaurant-cmr.user';

/// Tokens de la sesión del personal en memoria. El cliente HTTP los lee de aquí (y no de
/// LocalStorage) para que funcionen también con "Mantener sesión" desactivado.
/// `SessionStore` los mantiene al día y escucha [onTokensChanged] / [onSessionExpired].
class AuthTokens {
  AuthTokens._();

  static String? accessToken;
  static String? refreshToken;

  /// Tras renovar los tokens: la sesión guarda el par nuevo.
  static void Function(String accessToken, String refreshToken)? onTokensChanged;

  /// El refresh token ya no sirve: hay que volver a iniciar sesión.
  static void Function()? onSessionExpired;
}
