import '../../core/utils/json.dart';
import '../auth/permissions.dart';

/// 'kitchen' | 'floor' | 'support' | 'management'
typedef EmployeeArea = String;

/// 'active' | 'on-leave' | 'inactive'
typedef EmployeeStatus = String;

/// 'ok' | 'low' | 'critical'
typedef InventoryStatus = String;

const List<EmployeeArea> employeeAreas = ['kitchen', 'floor', 'support', 'management'];
const List<EmployeeStatus> employeeStatuses = ['active', 'on-leave', 'inactive'];
const List<InventoryStatus> inventoryStatuses = ['ok', 'low', 'critical'];

bool isEmployeeArea(Object? value) => value is String && employeeAreas.contains(value);

bool isEmployeeStatus(Object? value) => value is String && employeeStatuses.contains(value);

bool isInventoryStatus(Object? value) => value is String && inventoryStatuses.contains(value);

bool _isId(Object? value) => value is String || value is num;

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.roleId,
    required this.roleName,
    required this.restaurantId,
    required this.restaurantName,
    required this.area,
    required this.status,
    required this.hiredAt,
    this.userId,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String roleId;
  final String roleName;
  final String restaurantId;
  final String restaurantName;
  final EmployeeArea area;
  final EmployeeStatus status;
  final String hiredAt;
  final String? userId;

  /// Equivalente a `isEmployee` + `toEmployee`: null si faltan campos obligatorios.
  static Employee? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);
    final userId = json['userId'];

    if (!_isId(json['id']) ||
        json['name'] is! String ||
        json['email'] is! String ||
        json['phone'] is! String ||
        !_isId(json['roleId']) ||
        json['roleName'] is! String ||
        !_isId(json['restaurantId']) ||
        json['restaurantName'] is! String ||
        !isEmployeeArea(json['area']) ||
        !isEmployeeStatus(json['status']) ||
        json['hiredAt'] is! String ||
        (userId != null && !_isId(userId))) {
      return null;
    }

    return Employee.fromJson(json);
  }

  factory Employee.fromJson(JsonMap json) => Employee(
        id: asId(json['id']),
        name: asString(json['name']),
        email: asString(json['email']),
        phone: asString(json['phone']),
        roleId: asId(json['roleId']),
        roleName: asString(json['roleName']),
        restaurantId: asId(json['restaurantId']),
        restaurantName: asString(json['restaurantName']),
        area: asString(json['area'], 'floor'),
        status: asString(json['status'], 'active'),
        hiredAt: asString(json['hiredAt']),
        userId: asStringOrNull(json['userId']),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'roleId': roleId,
        'roleName': roleName,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'area': area,
        'status': status,
        'hiredAt': hiredAt,
        'userId': userId,
      };

  Employee copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? roleId,
    String? roleName,
    String? restaurantId,
    String? restaurantName,
    EmployeeArea? area,
    EmployeeStatus? status,
    String? hiredAt,
    String? Function()? userId,
  }) =>
      Employee(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        roleId: roleId ?? this.roleId,
        roleName: roleName ?? this.roleName,
        restaurantId: restaurantId ?? this.restaurantId,
        restaurantName: restaurantName ?? this.restaurantName,
        area: area ?? this.area,
        status: status ?? this.status,
        hiredAt: hiredAt ?? this.hiredAt,
        userId: userId != null ? userId() : this.userId,
      );
}

class EmployeeDraft {
  const EmployeeDraft({
    required this.name,
    required this.email,
    required this.phone,
    required this.roleId,
    required this.restaurantId,
    required this.area,
    required this.status,
    this.userId,
  });

  final String name;
  final String email;
  final String phone;
  final String roleId;
  final String restaurantId;
  final EmployeeArea area;
  final EmployeeStatus status;
  final String? userId;

  factory EmployeeDraft.fromJson(JsonMap json) => EmployeeDraft(
        name: asString(json['name']),
        email: asString(json['email']),
        phone: asString(json['phone']),
        roleId: asId(json['roleId']),
        restaurantId: asId(json['restaurantId']),
        area: asString(json['area'], 'floor'),
        status: asString(json['status'], 'active'),
        userId: asStringOrNull(json['userId']),
      );

  JsonMap toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'roleId': roleId,
        'restaurantId': restaurantId,
        'area': area,
        'status': status,
        'userId': userId,
      };

  EmployeeDraft copyWith({
    String? name,
    String? email,
    String? phone,
    String? roleId,
    String? restaurantId,
    EmployeeArea? area,
    EmployeeStatus? status,
    String? Function()? userId,
  }) =>
      EmployeeDraft(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        roleId: roleId ?? this.roleId,
        restaurantId: restaurantId ?? this.restaurantId,
        area: area ?? this.area,
        status: status ?? this.status,
        userId: userId != null ? userId() : this.userId,
      );
}

class SystemUser {
  const SystemUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    required this.isBlocked,
    this.roleId,
    required this.restaurantIds,
    this.employeeId,
  });

  final String id;
  final String name;
  final String email;
  final bool isActive;
  final bool isBlocked;
  final String? roleId;

  /// Sedes a las que accede. Vacío = todas.
  final List<String> restaurantIds;
  final String? employeeId;

  /// Equivalente a `isSystemUser` + `toSystemUser`.
  static SystemUser? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);

    if (!_isId(json['id']) || json['name'] is! String || json['email'] is! String || json['isActive'] is! bool) {
      return null;
    }

    return SystemUser.fromJson(json);
  }

  factory SystemUser.fromJson(JsonMap json) => SystemUser(
        id: asId(json['id']),
        name: asString(json['name']),
        email: asString(json['email']),
        isActive: asBool(json['isActive']),
        isBlocked: json['isBlocked'] == true,
        roleId: json['roleId'] is String ? json['roleId'] as String : null,
        restaurantIds: asStringList(json['restaurantIds']),
        employeeId: json['employeeId'] is String ? json['employeeId'] as String : null,
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isActive': isActive,
        'isBlocked': isBlocked,
        'roleId': roleId,
        'restaurantIds': restaurantIds,
        'employeeId': employeeId,
      };

  SystemUser copyWith({
    String? id,
    String? name,
    String? email,
    bool? isActive,
    bool? isBlocked,
    String? Function()? roleId,
    List<String>? restaurantIds,
    String? Function()? employeeId,
  }) =>
      SystemUser(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        isActive: isActive ?? this.isActive,
        isBlocked: isBlocked ?? this.isBlocked,
        roleId: roleId != null ? roleId() : this.roleId,
        restaurantIds: restaurantIds ?? this.restaurantIds,
        employeeId: employeeId != null ? employeeId() : this.employeeId,
      );
}

class SystemUserDraft {
  const SystemUserDraft({this.roleId, required this.restaurantIds, this.employeeId});

  final String? roleId;
  final List<String> restaurantIds;
  final String? employeeId;

  factory SystemUserDraft.fromJson(JsonMap json) => SystemUserDraft(
        roleId: asStringOrNull(json['roleId']),
        restaurantIds: asStringList(json['restaurantIds']),
        employeeId: asStringOrNull(json['employeeId']),
      );

  JsonMap toJson() => {'roleId': roleId, 'restaurantIds': restaurantIds, 'employeeId': employeeId};

  SystemUserDraft copyWith({String? Function()? roleId, List<String>? restaurantIds, String? Function()? employeeId}) =>
      SystemUserDraft(
        roleId: roleId != null ? roleId() : this.roleId,
        restaurantIds: restaurantIds ?? this.restaurantIds,
        employeeId: employeeId != null ? employeeId() : this.employeeId,
      );
}

class Role {
  const Role({required this.id, required this.name, required this.description, required this.permissions});

  final String id;
  final String name;
  final String description;
  final List<Permission> permissions;

  /// Equivalente a `isRole` + `toRole` (descarta permisos desconocidos).
  static Role? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);
    final permissions = json['permissions'];

    if (!_isId(json['id']) ||
        json['name'] is! String ||
        json['description'] is! String ||
        permissions is! List ||
        !permissions.every((permission) => permission is String)) {
      return null;
    }

    return Role.fromJson(json);
  }

  factory Role.fromJson(JsonMap json) => Role(
        id: asId(json['id']),
        name: asString(json['name']),
        description: asString(json['description']),
        permissions: asStringList(json['permissions']).where(isPermission).toList(),
      );

  JsonMap toJson() => {'id': id, 'name': name, 'description': description, 'permissions': permissions};

  Role copyWith({String? id, String? name, String? description, List<Permission>? permissions}) => Role(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        permissions: permissions ?? this.permissions,
      );
}

class RoleDraft {
  const RoleDraft({required this.name, required this.description, required this.permissions});

  final String name;
  final String description;
  final List<Permission> permissions;

  factory RoleDraft.fromJson(JsonMap json) => RoleDraft(
        name: asString(json['name']),
        description: asString(json['description']),
        permissions: asStringList(json['permissions']).where(isPermission).toList(),
      );

  JsonMap toJson() => {'name': name, 'description': description, 'permissions': permissions};

  RoleDraft copyWith({String? name, String? description, List<Permission>? permissions}) => RoleDraft(
        name: name ?? this.name,
        description: description ?? this.description,
        permissions: permissions ?? this.permissions,
      );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.status,
    required this.supplier,
    required this.updatedAt,
    required this.isActive,
  });

  final String id;
  final String restaurantId;
  final String name;
  final String unit;
  final double stock;
  final double minStock;
  final InventoryStatus status;
  final String supplier;
  final String updatedAt;
  final bool isActive;

  /// Equivalente a `isInventoryItem` + `toInventoryItem`.
  static InventoryItem? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);

    if (!_isId(json['id']) ||
        !_isId(json['restaurantId']) ||
        json['name'] is! String ||
        json['unit'] is! String ||
        json['stock'] is! num ||
        json['minStock'] is! num ||
        !isInventoryStatus(json['status']) ||
        json['supplier'] is! String ||
        json['updatedAt'] is! String) {
      return null;
    }

    return InventoryItem.fromJson(json);
  }

  factory InventoryItem.fromJson(JsonMap json) => InventoryItem(
        id: asId(json['id']),
        restaurantId: asId(json['restaurantId']),
        name: asString(json['name']),
        unit: asString(json['unit']),
        stock: asDouble(json['stock']),
        minStock: asDouble(json['minStock']),
        status: asString(json['status'], 'ok'),
        supplier: asString(json['supplier']),
        updatedAt: asString(json['updatedAt']),
        isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      );

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'name': name,
        'unit': unit,
        'stock': stock,
        'minStock': minStock,
        'status': status,
        'supplier': supplier,
        'updatedAt': updatedAt,
        'isActive': isActive,
      };

  InventoryItem copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? unit,
    double? stock,
    double? minStock,
    InventoryStatus? status,
    String? supplier,
    String? updatedAt,
    bool? isActive,
  }) =>
      InventoryItem(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        status: status ?? this.status,
        supplier: supplier ?? this.supplier,
        updatedAt: updatedAt ?? this.updatedAt,
        isActive: isActive ?? this.isActive,
      );
}

class InventoryItemDraft {
  const InventoryItemDraft({
    required this.restaurantId,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.supplier,
    required this.isActive,
  });

  final String restaurantId;
  final String name;
  final String unit;
  final double stock;
  final double minStock;
  final String supplier;
  final bool isActive;

  factory InventoryItemDraft.fromJson(JsonMap json) => InventoryItemDraft(
        restaurantId: asId(json['restaurantId']),
        name: asString(json['name']),
        unit: asString(json['unit']),
        stock: asDouble(json['stock']),
        minStock: asDouble(json['minStock']),
        supplier: asString(json['supplier']),
        isActive: asBool(json['isActive'], true),
      );

  JsonMap toJson() => {
        'restaurantId': restaurantId,
        'name': name,
        'unit': unit,
        'stock': stock,
        'minStock': minStock,
        'supplier': supplier,
        'isActive': isActive,
      };

  InventoryItemDraft copyWith({
    String? restaurantId,
    String? name,
    String? unit,
    double? stock,
    double? minStock,
    String? supplier,
    bool? isActive,
  }) =>
      InventoryItemDraft(
        restaurantId: restaurantId ?? this.restaurantId,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        supplier: supplier ?? this.supplier,
        isActive: isActive ?? this.isActive,
      );
}
