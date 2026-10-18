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

Future<AuthSession> _toSession(JsonUser user) async => AuthSession(accessToken: 'json-${user.id}', user: await _toAuthUser(user));

void _assertCanSignIn(JsonUser user) {
  if (user.isBlocked) {
    throw HttpError('Esta cuenta está bloqueada. Contactá a un administrador.', 403);
  }

  if (!user.isActive) {
    throw HttpError('Esta cuenta está desactivada. Contactá a un administrador.', 403);
  }
}

/// Vuelve a leer el usuario y su rol (permisos actualizados, bloqueo, desactivación).
Future<AuthUser?> refreshAuthUser(String userId) async {
  try {
    final user = JsonUser.tryParse(await http('/users/$userId'));

    if (user == null || user.isBlocked || !user.isActive) {
      return null;
    }

    return await _toAuthUser(user);
  } on HttpError catch (error) {
    if (error.status == 404) {
      return null;
    }

    rethrow;
  }
}

String _normalizeEmail(String email) => email.trim().toLowerCase();

Future<List<JsonUser>> _findUsersByEmail(String email) async {
  final users = await http('/users?email=${encodeQuery(email)}');
  return asList(users).map(JsonUser.tryParse).whereType<JsonUser>().toList();
}

Future<AuthSession> login(LoginPayload payload) async {
  final email = _normalizeEmail(payload.email);
  final users = await _findUsersByEmail(email);
  final matches = users.where((candidate) => _normalizeEmail(candidate.email) == email && candidate.password == payload.password);

  if (matches.isEmpty) {
    throw HttpError('Correo o contraseña incorrectos', 401);
  }

  final user = matches.first;
  _assertCanSignIn(user);

  return _toSession(user);
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
