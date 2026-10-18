import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/time.dart';
import '../../stores/diner_store.dart';
import 'types.dart';

/// Registro de `/customers` tal cual lo guarda json-server (incluye la contraseña).
class _JsonCustomer {
  const _JsonCustomer(this.raw);

  final JsonMap raw;

  String get email => raw['email'] as String;
  String get password => raw['password'] as String;
}

bool _isJsonCustomer(Object? value) {
  if (value is! Map) {
    return false;
  }

  return (value['id'] is String || value['id'] is num) &&
      value['name'] is String &&
      value['email'] is String &&
      value['password'] is String;
}

DinerCustomer _toCustomer(_JsonCustomer value) => DinerCustomer.fromJson(value.raw);

String _normalizeEmail(String email) => email.trim().toLowerCase();

Future<List<_JsonCustomer>> _findCustomers(String email) async {
  final payload = await http('/customers?email=${encodeQuery(email)}');
  return payload is List ? payload.where(_isJsonCustomer).map((item) => _JsonCustomer(asMap(item))).toList() : [];
}

/// Cuenta opcional del comensal. Es independiente de las cuentas del personal.
Future<DinerCustomer> loginCustomer(String email, String password) async {
  final normalized = _normalizeEmail(email);
  final customers = await _findCustomers(normalized);

  for (final customer in customers) {
    if (_normalizeEmail(customer.email) == normalized && customer.password == password) {
      return _toCustomer(customer);
    }
  }

  throw HttpError('Correo o contraseña incorrectos', 401);
}

Future<DinerCustomer> registerCustomer(String name, String email, String password) async {
  final normalized = _normalizeEmail(email);

  if ((await _findCustomers(normalized)).isNotEmpty) {
    throw HttpError('Ya existe una cuenta con este correo', 409);
  }

  final created = await http('/customers', method: 'POST', body: {
    'name': name.trim(),
    'email': normalized,
    'password': password,
    'phone': null,
    'birthday': null,
    'dietaryPreferences': <String>[],
    'allergens': <String>[],
    'marketingOptIn': false,
    'createdAt': nowIso(),
  });

  if (!_isJsonCustomer(created)) {
    throw HttpError('No se pudo crear la cuenta', 500);
  }

  return _toCustomer(_JsonCustomer(asMap(created)));
}

CustomerProfile _toProfile(_JsonCustomer value) => CustomerProfile.fromJson(value.raw);

Future<_JsonCustomer> _fetchJsonCustomer(String id) async {
  final payload = await http('/customers/$id');

  if (!_isJsonCustomer(payload)) {
    throw HttpError('No encontramos tu cuenta', 404);
  }

  return _JsonCustomer(asMap(payload));
}

/// Contrato pensado para el backend: GET /customers/me
Future<CustomerProfile> fetchCustomerProfile(String id) async {
  return _toProfile(await _fetchJsonCustomer(id));
}

/// Contrato pensado para el backend: PATCH /customers/me
Future<CustomerProfile> updateCustomerProfile(String id, CustomerProfileDraft draft) async {
  final phone = draft.phone?.trim() ?? '';
  final birthday = draft.birthday ?? '';
  final payload = await http('/customers/$id', method: 'PATCH', body: {
    'name': draft.name.trim(),
    'phone': phone.isNotEmpty ? phone : null,
    'birthday': birthday.isNotEmpty ? birthday : null,
    'dietaryPreferences': draft.dietaryPreferences,
    'allergens': draft.allergens,
    'marketingOptIn': draft.marketingOptIn,
  });

  if (!_isJsonCustomer(payload)) {
    throw HttpError('No se pudo guardar tu perfil', 500);
  }

  return _toProfile(_JsonCustomer(asMap(payload)));
}

/// Contrato pensado para el backend: POST /customers/me/password. Con json-server la
/// contraseña actual se compara en el cliente; el backend real lo hará del lado servidor.
Future<void> changeCustomerPassword(String id, String currentPassword, String nextPassword) async {
  final customer = await _fetchJsonCustomer(id);

  if (customer.password != currentPassword) {
    throw HttpError('La contraseña actual no es correcta', 401);
  }

  await http('/customers/$id', method: 'PATCH', body: {'password': nextPassword});
}
