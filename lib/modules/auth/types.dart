import '../../core/utils/json.dart';
import 'permissions.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roleId,
    required this.roleName,
    required this.permissions,
    required this.restaurantIds,
    required this.employeeId,
  });

  final String id;
  final String name;
  final String email;
  final String? roleId;
  final String? roleName;
  final List<Permission> permissions;

  /// Sedes a las que tiene acceso. Vacío = todas las sedes de la organización.
  final List<String> restaurantIds;
  final String? employeeId;

  factory AuthUser.fromJson(JsonMap json) => AuthUser(
        id: asId(json['id']),
        name: asString(json['name']),
        email: asString(json['email']),
        roleId: asStringOrNull(json['roleId']),
        roleName: asStringOrNull(json['roleName']),
        permissions: asStringList(json['permissions']).where(isPermission).toList(),
        restaurantIds: asStringList(json['restaurantIds']),
        employeeId: asStringOrNull(json['employeeId']),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'roleId': roleId,
        'roleName': roleName,
        'permissions': permissions,
        'restaurantIds': restaurantIds,
        'employeeId': employeeId,
      };
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;
}

class LoginPayload {
  const LoginPayload({required this.email, required this.password});

  final String email;
  final String password;
}

class RegisterPayload {
  const RegisterPayload({required this.name, required this.email, required this.password});

  final String name;
  final String email;
  final String password;
}

class JsonUser {
  const JsonUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.isActive,
    this.isBlocked = false,
    this.roleId,
    this.restaurantIds = const [],
    this.employeeId,
    this.phone,
    this.jobTitle,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String password;
  final bool isActive;
  final bool isBlocked;
  final String? roleId;
  final List<String> restaurantIds;
  final String? employeeId;
  final String? phone;
  final String? jobTitle;
  final String? createdAt;

  /// Equivalente a `isJsonUser`: null si faltan campos obligatorios.
  static JsonUser? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);
    final id = json['id'];

    if ((id is! String && id is! num) ||
        json['name'] is! String ||
        json['email'] is! String ||
        json['password'] is! String ||
        json['isActive'] is! bool) {
      return null;
    }

    return JsonUser(
      id: asId(id),
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      isActive: json['isActive'] as bool,
      isBlocked: asBool(json['isBlocked']),
      roleId: asStringOrNull(json['roleId']),
      restaurantIds: asStringList(json['restaurantIds']),
      employeeId: asStringOrNull(json['employeeId']),
      phone: asStringOrNull(json['phone']),
      jobTitle: asStringOrNull(json['jobTitle']),
      createdAt: asStringOrNull(json['createdAt']),
    );
  }
}

/// Sede a cargo de un usuario del restaurante, resumida para su perfil.
class StaffProfileSite {
  const StaffProfileSite({required this.id, required this.slug, required this.name, required this.city, required this.imageUrl});

  final String id;
  final String slug;
  final String name;
  final String city;
  final String imageUrl;
}

class StaffProfileEmployee {
  const StaffProfileEmployee({required this.area, required this.status, this.hiredAt, this.restaurantName});

  final String area;
  final String status;
  final String? hiredAt;
  final String? restaurantName;
}

/// Perfil del dueño o del personal del restaurante. Distinto al del cliente:
/// gira en torno a su rol, sus permisos y las sedes que gestiona.
class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.jobTitle,
    required this.createdAt,
    required this.roleName,
    required this.permissions,
    required this.allRestaurants,
    required this.restaurants,
    required this.employee,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;

  /// Cargo que el usuario muestra (ej: "Fundador y propietario"); el rol define los permisos.
  final String? jobTitle;
  final String? createdAt;
  final String? roleName;
  final List<Permission> permissions;

  /// true = sin restricción de sede (ve toda la organización).
  final bool allRestaurants;
  final List<StaffProfileSite> restaurants;

  /// Ficha de empleado vinculada, si la tiene.
  final StaffProfileEmployee? employee;
}

class StaffProfileDraft {
  const StaffProfileDraft({required this.name, this.phone, this.jobTitle});

  final String name;
  final String? phone;
  final String? jobTitle;
}
