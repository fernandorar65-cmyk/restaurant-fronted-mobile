import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../restaurants/api.dart';
import 'permissions.dart';
import 'types.dart';

class _RoleAccess {
  const _RoleAccess(this.name, this.permissions);

  final String name;
  final List<Permission> permissions;
}

Future<_RoleAccess?> _fetchRoleAccess(String? roleId) async {
  if (roleId == null || roleId.isEmpty) {
    return null;
  }

  try {
    final role = await http('/roles/$roleId');

    if (role is! Map || !role.containsKey('name') || !role.containsKey('permissions')) {
      return null;
    }

    final permissions = asList(role['permissions']).where(isPermission).cast<String>().toList();
    return _RoleAccess(role['name'] is String ? role['name'] as String : '', permissions);
  } on HttpError catch (error) {
    if (error.status == 404) {
      return null;
    }

    rethrow;
  }
}

Future<AuthUser> _toAuthUser(JsonUser user) async {
  final role = await _fetchRoleAccess(user.roleId);

  return AuthUser(
    id: user.id,
    name: user.name,
    email: user.email,
    roleId: user.roleId,
    roleName: role?.name,
    permissions: role?.permissions ?? const [],
    restaurantIds: user.restaurantIds,
    employeeId: user.employeeId,
  );
}

// Pendiente de migrar: el registro todavía usa las rutas de json-server y no tiene refresh token.
Future<AuthSession> _toSession(JsonUser user) async =>
    AuthSession(accessToken: 'json-${user.id}', refreshToken: '', user: await _toAuthUser(user));

/// Vuelve a leer el usuario y su acceso (permisos actualizados, bloqueo, desactivación)
/// con GET /api/v1/owner/me/profile. Devuelve null si la cuenta ya no puede entrar.
Future<AuthUser?> refreshAuthUser(String userId) async {
  try {
    final profile = await http('/api/v1/owner/me/profile');
    return profile is Map ? _authUserFromStaff(asMap(profile)) : null;
  } on HttpError catch (error) {
    if (error.status == 401 || error.status == 404 || error.errorCode == 'ACCOUNT_DISABLED') {
      return null;
    }

    rethrow;
  }
}

/// Permisos del backend → permisos de la app. El backend usa `área.acción`
/// (`attentions.manage`, `catalog.manage`…); el portal sigue usando los suyos.
const Map<String, List<Permission>> _backendPermissions = {
  'organizations.manage': [Permissions.orgManage],
  'settings.manage': [Permissions.orgManage],
  'restaurants.manage': [Permissions.orgManage, Permissions.sitesManage],
  'staff.manage': [Permissions.staffManage, Permissions.usersManage],
  'attentions.manage': [Permissions.ordersManage],
  'kitchen.manage': [Permissions.kitchenManage],
  'catalog.manage': [Permissions.menuManage],
  'payments.manage': [Permissions.paymentsManage],
  'inventory.manage': [Permissions.inventoryManage],
  'finance.read': [Permissions.reportsView],
  'finance.manage': [Permissions.reportsView],
};

List<Permission> _toAppPermissions(List<String> codes, {required bool isPlatformAdmin}) {
  if (isPlatformAdmin) {
    return permissionsList;
  }

  return {for (final code in codes) ...?_backendPermissions[code]}.toList();
}

/// Arma el usuario de la app con `StaffLoginResponseDto` / `StaffProfileResponseDto`.
/// La app maneja una organización a la vez: toma la primera membresía activa.
AuthUser _authUserFromStaff(JsonMap data) {
  final user = asMap(data['user']);
  final accesses = asMapList(data['access']);
  final access = accesses.isEmpty ? null : accesses.first;
  final role = access == null ? null : asMapOrNull(access['role']);
  final organizationId = access == null ? null : asStringOrNull(access['organizationId']);
  final employments = asMapList(data['employments']);
  final employment = employments.where((item) => asStringOrNull(item['organizationId']) == organizationId).firstOrNull;
  final name = [asString(user['firstName']), asString(user['lastName'])].where((part) => part.trim().isNotEmpty).join(' ');

  return AuthUser(
    id: asId(user['id']),
    name: name.isEmpty ? asString(user['email']) : name,
    email: asString(user['email']),
    roleId: role == null ? null : asStringOrNull(role['id']),
    roleName: role == null ? null : asStringOrNull(role['name']),
    permissions: _toAppPermissions(
      access == null ? const [] : asStringList(access['permissions']),
      isPlatformAdmin: asBool(data['isPlatformAdmin']),
    ),
    // Lista vacía = todas las sedes, igual que `allRestaurants: true` en el backend.
    restaurantIds: access == null || asBool(access['allRestaurants']) ? const [] : asStringList(access['restaurantIds']),
    employeeId: employment == null ? null : asStringOrNull(employment['employeeId']),
    organizationId: organizationId,
  );
}

/// Cierra la sesión en el backend (invalida el refresh token). Recibe el access token
/// porque la sesión local ya se borró. Si falla, la sesión local se cierra igual.
Future<void> logout({required String refreshToken, String? accessToken}) async {
  try {
    await http(
      '/api/v1/owner/auth/logout',
      method: 'POST',
      body: {'refreshToken': refreshToken},
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
  } catch (_) {
    // El token vence solo; no bloquea el cierre de sesión local.
  }
}

String _normalizeEmail(String email) => email.trim().toLowerCase();

Future<List<JsonUser>> _findUsersByEmail(String email) async {
  final users = await http('/users?email=${encodeQuery(email)}');
  return asList(users).map(JsonUser.tryParse).whereType<JsonUser>().toList();
}

/// POST /api/v1/owner/auth/login: el backend valida la contraseña y devuelve los tokens
/// junto con el acceso por organización (rol, sedes y permisos).
Future<AuthSession> login(LoginPayload payload) async {
  final data = await http(
    '/api/v1/owner/auth/login',
    method: 'POST',
    body: {'email': _normalizeEmail(payload.email), 'password': payload.password},
  );

  if (data is! Map || data['accessToken'] is! String || data['refreshToken'] is! String) {
    throw HttpError('Respuesta de inicio de sesión inesperada', 500);
  }

  final json = asMap(data);
  return AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: _authUserFromStaff(json),
  );
}

Future<AuthSession> register(RegisterPayload payload) async {
  final email = _normalizeEmail(payload.email);
  final existingUsers = await _findUsersByEmail(email);

  if (existingUsers.isNotEmpty) {
    throw HttpError('Ya existe una cuenta con este correo', 409);
  }

  final created = JsonUser.tryParse(await http('/users', method: 'POST', body: {
    'name': payload.name.trim(),
    'email': email,
    'password': payload.password,
    'isActive': true,
    'isBlocked': false,
    'roleId': null,
    'restaurantIds': <String>[],
    'employeeId': null,
  }));

  if (created == null) {
    throw HttpError('No se pudo crear la cuenta', 500);
  }

  return _toSession(created);
}

Future<JsonUser> _fetchJsonUser(String id) async {
  final user = JsonUser.tryParse(await http('/users/$id'));

  if (user == null) {
    throw HttpError('No encontramos tu usuario', 404);
  }

  return user;
}

Future<StaffProfileEmployee?> _fetchEmployeeSummary(String? employeeId) async {
  if (employeeId == null || employeeId.isEmpty) {
    return null;
  }

  try {
    final value = await http('/employees/$employeeId');

    if (value is! Map) {
      return null;
    }

    final record = asMap(value);
    return StaffProfileEmployee(
      area: asString(record['area']),
      status: asString(record['status']),
      hiredAt: asStringOrNull(record['hiredAt']),
      restaurantName: asStringOrNull(record['restaurantName']),
    );
  } catch (_) {
    return null;
  }
}

/// Contrato pensado para el backend: GET /users/me/profile
Future<StaffProfile> fetchStaffProfile(String userId) async {
  final user = await _fetchJsonUser(userId);
  final results = await Future.wait([
    _toAuthUser(user),
    fetchRestaurants(),
    _fetchEmployeeSummary(user.employeeId),
  ]);
  final authUser = results[0] as AuthUser;
  final restaurants = results[1] as List;
  final employee = results[2] as StaffProfileEmployee?;
  final allRestaurants = authUser.restaurantIds.isEmpty;

  return StaffProfile(
    id: authUser.id,
    name: user.name,
    email: user.email,
    phone: (user.phone ?? '').isNotEmpty ? user.phone : null,
    jobTitle: (user.jobTitle ?? '').isNotEmpty ? user.jobTitle : null,
    createdAt: user.createdAt,
    roleName: authUser.roleName,
    permissions: authUser.permissions,
    allRestaurants: allRestaurants,
    restaurants: restaurants
        .where((site) => allRestaurants || authUser.restaurantIds.contains(site.id))
        .map((site) => StaffProfileSite(id: site.id, slug: site.slug, name: site.name, city: site.city, imageUrl: site.imageUrl))
        .toList(),
    employee: employee,
  );
}

/// Contrato pensado para el backend: PATCH /users/me/profile
Future<void> updateStaffProfile(String userId, StaffProfileDraft draft) async {
  String? clean(String? value) => (value?.trim() ?? '').isEmpty ? null : value!.trim();

  await http('/users/$userId', method: 'PATCH', body: {
    'name': draft.name.trim(),
    'phone': clean(draft.phone),
    'jobTitle': clean(draft.jobTitle),
  });
}

/// Contrato pensado para el backend: POST /users/me/password. Con json-server la
/// contraseña actual se compara en el cliente; el backend real lo hará del lado servidor.
Future<void> changeStaffPassword(String userId, String currentPassword, String nextPassword) async {
  final user = await _fetchJsonUser(userId);

  if (user.password != currentPassword) {
    throw HttpError('La contraseña actual no es correcta', 401);
  }

  await http('/users/$userId', method: 'PATCH', body: {'password': nextPassword});
}

/// Agrega una sede a las sedes de un usuario con acceso restringido (p. ej. el dueño
/// que acaba de crearla). Un usuario sin restricción (lista vacía) ya ve todas.
/// Contrato pensado para el backend: lo hará el propio POST /restaurants.
Future<void> grantRestaurantAccess(String userId, String restaurantId) async {
  final user = await _fetchJsonUser(userId);
  final current = user.restaurantIds;

  if (current.isEmpty || current.contains(restaurantId)) {
    return;
  }

  await http('/users/$userId', method: 'PATCH', body: {
    'restaurantIds': [...current, restaurantId],
  });
}
