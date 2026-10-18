import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/time.dart';
import 'types.dart';

/// Crítico por debajo de la mitad del mínimo, bajo por debajo del mínimo.
InventoryStatus inventoryStatusFor(num stock, num minStock) {
  if (stock < minStock / 2) {
    return 'critical';
  }

  return stock < minStock ? 'low' : 'ok';
}

Future<List<Employee>> fetchEmployees() async {
  final payload = await http('/employees');

  if (payload is! List) {
    return [];
  }

  return payload.map(Employee.tryParse).whereType<Employee>().toList();
}

Future<List<Role>> fetchRoles() async {
  final payload = await http('/roles');

  if (payload is! List) {
    return [];
  }

  return payload.map(Role.tryParse).whereType<Role>().toList();
}

Future<List<InventoryItem>> fetchInventoryItems() async {
  final payload = await http('/inventoryItems');

  if (payload is! List) {
    return [];
  }

  return payload.map(InventoryItem.tryParse).whereType<InventoryItem>().toList();
}

/// En TS el borrador es `EmployeeDraft & { roleName, restaurantName }`: aquí van como parámetros con nombre.
Future<Employee> updateEmployee(
  String id,
  EmployeeDraft draft, {
  required String roleName,
  required String restaurantName,
}) async {
  final payload = await http(
    '/employees/$id',
    method: 'PATCH',
    body: {...draft.toJson(), 'roleName': roleName, 'restaurantName': restaurantName},
  );

  final employee = Employee.tryParse(payload);

  if (employee == null) {
    throw HttpError('No se pudo actualizar el empleado.', 500);
  }

  return employee;
}

Future<Employee> createEmployee(EmployeeDraft draft, {required String roleName, required String restaurantName}) async {
  final payload = await http(
    '/employees',
    method: 'POST',
    body: {
      ...draft.toJson(),
      'roleName': roleName,
      'restaurantName': restaurantName,
      'hiredAt': nowIso().substring(0, 10),
    },
  );

  final employee = Employee.tryParse(payload);

  if (employee == null) {
    throw HttpError('No se pudo crear el empleado.', 500);
  }

  return employee;
}

/// Mantiene el vínculo usuario ↔ empleado en ambos sentidos al cambiarlo desde el empleado.
Future<void> syncEmployeeUserLink(String employeeId, String? previousUserId, String? nextUserId) async {
  if (previousUserId == nextUserId) {
    return;
  }

  if (previousUserId != null && previousUserId.isNotEmpty) {
    await http('/users/$previousUserId', method: 'PATCH', body: {'employeeId': null});
  }

  if (nextUserId != null && nextUserId.isNotEmpty) {
    await http('/users/$nextUserId', method: 'PATCH', body: {'employeeId': employeeId});
  }
}

Future<void> deleteEmployee(Employee employee) async {
  final userId = employee.userId;

  if (userId != null && userId.isNotEmpty) {
    await http('/users/$userId', method: 'PATCH', body: {'employeeId': null});
  }

  await http('/employees/${employee.id}', method: 'DELETE');
}

Future<InventoryItem> _patchInventoryItem(String id, JsonMap body) async {
  final payload = await http('/inventoryItems/$id', method: 'PATCH', body: {...body, 'updatedAt': nowIso()});
  final item = InventoryItem.tryParse(payload);

  if (item == null) {
    throw HttpError('No se pudo actualizar el inventario.', 500);
  }

  return item;
}

Future<InventoryItem> updateInventoryStock(InventoryItem item, double stock) async {
  if (stock < 0) {
    throw HttpError('La cantidad no puede ser negativa.', 400);
  }

  return _patchInventoryItem(item.id, {'stock': stock, 'status': inventoryStatusFor(stock, item.minStock)});
}

Future<InventoryItem> createInventoryItem(InventoryItemDraft draft) async {
  final payload = await http(
    '/inventoryItems',
    method: 'POST',
    body: {
      ...draft.toJson(),
      'status': inventoryStatusFor(draft.stock, draft.minStock),
      'updatedAt': nowIso(),
    },
  );

  final item = InventoryItem.tryParse(payload);

  if (item == null) {
    throw HttpError('No se pudo crear el insumo.', 500);
  }

  return item;
}

Future<InventoryItem> updateInventoryItem(String id, InventoryItemDraft draft) =>
    _patchInventoryItem(id, {...draft.toJson(), 'status': inventoryStatusFor(draft.stock, draft.minStock)});

Future<Role> createRole(RoleDraft draft) async {
  final role = Role.tryParse(await http('/roles', method: 'POST', body: draft.toJson()));

  if (role == null) {
    throw HttpError('No se pudo crear el rol.', 500);
  }

  return role;
}

Future<Role> updateRole(String id, RoleDraft draft) async {
  final role = Role.tryParse(await http('/roles/$id', method: 'PATCH', body: draft.toJson()));

  if (role == null) {
    throw HttpError('No se pudo actualizar el rol.', 500);
  }

  return role;
}

Future<void> deleteRole(String id) async {
  await http('/roles/$id', method: 'DELETE');
}

Future<List<SystemUser>> fetchUsers() async {
  final payload = await http('/users');

  if (payload is! List) {
    return [];
  }

  return payload.map(SystemUser.tryParse).whereType<SystemUser>().toList();
}

Future<SystemUser> _patchUser(String id, JsonMap body) async {
  final user = SystemUser.tryParse(await http('/users/$id', method: 'PATCH', body: body));

  if (user == null) {
    throw HttpError('No se pudo actualizar la cuenta.', 500);
  }

  return user;
}

Future<SystemUser> updateUserActive(String id, bool isActive) => _patchUser(id, {'isActive': isActive});

Future<SystemUser> updateUserBlocked(String id, bool isBlocked) => _patchUser(id, {'isBlocked': isBlocked});

/// Asigna rol, sedes y empleado a una cuenta. Mantiene el vínculo en ambos
/// sentidos (empleado.userId ↔ usuario.employeeId).
Future<SystemUser> updateUserAccess(SystemUser user, SystemUserDraft draft) async {
  final currentEmployeeId = user.employeeId;
  final nextEmployeeId = draft.employeeId;

  if (currentEmployeeId != null && currentEmployeeId.isNotEmpty && currentEmployeeId != nextEmployeeId) {
    await http('/employees/$currentEmployeeId', method: 'PATCH', body: {'userId': null});
  }

  if (nextEmployeeId != null && nextEmployeeId.isNotEmpty && nextEmployeeId != currentEmployeeId) {
    final employees = await fetchEmployees();
    final previousOwner = employees.where((employee) => employee.id == nextEmployeeId).firstOrNull?.userId;

    if (previousOwner != null && previousOwner.isNotEmpty && previousOwner != user.id) {
      await http('/users/$previousOwner', method: 'PATCH', body: {'employeeId': null});
    }

    await http('/employees/$nextEmployeeId', method: 'PATCH', body: {'userId': user.id});
  }

  return _patchUser(user.id, draft.toJson());
}
