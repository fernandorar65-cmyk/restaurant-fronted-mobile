import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../stores/diner_store.dart';
import 'types.dart';

const _auth = '/api/v1/customer/auth';
const _me = '/api/v1/customer/me';

String _name(JsonMap data) =>
    [asString(data['firstName']), asString(data['lastName'])].where((part) => part.isNotEmpty).join(' ');

JsonMap _nameFields(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return {'firstName': parts.first, 'lastName': parts.skip(1).join(' ')};
}

Future<void> loginCustomer(DinerStore diner, String email, String password) =>
    _startSession(diner, 'login', {'email': email.trim().toLowerCase(), 'password': password});

Future<void> registerCustomer(DinerStore diner, String name, String email, String password) =>
    _startSession(diner, 'register', {
      ..._nameFields(name),
      'email': email.trim().toLowerCase(),
      'password': password,
    });

Future<void> _startSession(DinerStore diner, String action, JsonMap body) async {
  final data = asMap(await http('$_auth/$action', method: 'POST', body: body, authenticated: false));
  final user = asMap(data['user']);
  final access = asString(data['accessToken']);
  final refresh = asString(data['refreshToken']);
  if (access.isEmpty || refresh.isEmpty || asId(user['id']).isEmpty) {
    throw HttpError('Respuesta de sesión inesperada', 500);
  }
  diner.startCustomerSession(
    DinerCustomer.fromJson({...user, 'name': _name(user)}),
    accessToken: access,
    refreshToken: refresh,
  );
}

CustomerProfile _profile(Object? response) {
  final data = asMap(response);
  List<String> list(Object? value) => asString(value).split(',').map((part) => part.trim())
      .where((part) => part.isNotEmpty).toList();
  return CustomerProfile.fromJson({
    ...data,
    'name': _name(data),
    'birthday': data['birthDate'],
    'dietaryPreferences': list(data['dietaryPreferences']),
    'allergens': list(data['allergies']),
  });
}

Future<CustomerProfile> fetchCustomerProfile(DinerStore diner) async =>
    _profile(await diner.customerRequest(_me));

Future<CustomerProfile> updateCustomerProfile(DinerStore diner, CustomerProfileDraft draft) async =>
    _profile(await diner.customerRequest(_me, method: 'PATCH', body: {
      ..._nameFields(draft.name),
      'phone': asString(draft.phone).trim().isEmpty ? null : draft.phone!.trim(),
      'birthDate': draft.birthday,
      'dietaryPreferences': draft.dietaryPreferences.join(', '),
      'allergies': draft.allergens.isEmpty ? null : draft.allergens.join(', '),
      'marketingOptIn': draft.marketingOptIn,
    }));

Future<void> changeCustomerPassword(DinerStore diner, String currentPassword, String nextPassword) async {
  await diner.customerRequest('$_me/password', method: 'PATCH', body: {
    'currentPassword': currentPassword,
    'newPassword': nextPassword,
  });
}

Future<List<CustomerVisit>> fetchCustomerVisits(DinerStore diner) async {
  final visits = <CustomerVisit>[];
  var page = 1;
  int totalPages;
  do {
    final data = asMap(await diner.customerRequest('$_me/attentions?page=$page&limit=100'));
    visits.addAll(asMapList(data['items']).map(CustomerVisit.fromJson));
    totalPages = asInt(asMap(data['meta'])['totalPages']);
    page++;
  } while (page <= totalPages);
  return visits;
}
