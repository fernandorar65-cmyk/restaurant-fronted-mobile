import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/string.dart';
import 'types.dart';

bool _isId(Object? value) => value is String || value is num;

bool _isOrganization(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isId(value['id']) && value['name'] is String && value['code'] is String;
}

bool _isRestaurantOperationalStatus(Object? value) => value == 'active' || value == 'inactive' || value == 'suspended';

bool _isRestaurantSite(Object? value) {
  if (value is! Map || value['kpis'] is! Map) {
    return false;
  }

  final kpis = value['kpis'] as Map;
  final category = value['category'];
  final badgeTone = value['badgeTone'];

  return _isId(value['id']) &&
      value['code'] is String &&
      value['name'] is String &&
      value['city'] is String &&
      value['address'] is String &&
      value['imageUrl'] is String &&
      (category == 'fine-dining' || category == 'bistro' || category == 'lab') &&
      value['categoryLabel'] is String &&
      value['cuisine'] is String &&
      _isRestaurantOperationalStatus(value['status']) &&
      value['statusLabel'] is String &&
      value['badgeLabel'] is String &&
      (badgeTone == 'amber' || badgeTone == 'emerald' || badgeTone == 'wine' || badgeTone == 'blue') &&
      value['capacityLabel'] is String &&
      value['roleLabel'] is String &&
      kpis['revenueLabel'] is String &&
      kpis['revenueHint'] is String &&
      kpis['marginLabel'] is String &&
      kpis['stockLabel'] is String &&
      kpis['stockHint'] is String &&
      kpis['stockNote'] is String &&
      kpis['occupancyLabel'] is String &&
      kpis['occupancyHint'] is String &&
      kpis['occupancyPercent'] is num;
}

Organization _toOrganization(Object? value) => Organization.fromJson(asMap(value));

/// Normaliza la sede (slug, moneda, zona horaria, coordenadas y fulfillment por defecto).
RestaurantSite _toRestaurantSite(Object? value) => RestaurantSite.fromJson(asMap(value));

/// La sede puede recibir comensales y abrir atenciones.
bool isRestaurantOpen(RestaurantSite site) => site.status == 'active';

Future<List<Organization>> fetchOrganizations() async {
  final payload = await http('/organizations');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isOrganization).map(_toOrganization).toList();
}

Future<List<RestaurantSite>> fetchRestaurants() async {
  final payload = await http('/restaurants');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isRestaurantSite).map(_toRestaurantSite).toList();
}

/// Sede por su slug de URL. json-server no filtra por campos calculados, así que se busca en la lista.
Future<RestaurantSite?> fetchRestaurantBySlug(String slug) async {
  final restaurants = await fetchRestaurants();

  for (final site in restaurants) {
    if (site.slug == slug) return site;
  }

  return null;
}

Future<RestaurantSite?> fetchRestaurantById(String id) async {
  try {
    final payload = await http('/restaurants/$id');
    return _isRestaurantSite(payload) ? _toRestaurantSite(payload) : null;
  } on HttpError catch (error) {
    if (error.status == 404) {
      return null;
    }

    rethrow;
  }
}

class RestaurantDraft {
  const RestaurantDraft({
    required this.name,
    required this.city,
    required this.address,
    required this.cuisine,
    required this.status,
    required this.statusLabel,
    required this.category,
    required this.categoryLabel,
    required this.currency,
    required this.timezone,
  });

  final String name;
  final String city;
  final String address;
  final String cuisine;
  final RestaurantOperationalStatus status;
  final String statusLabel;
  final RestaurantCategory category;
  final String categoryLabel;
  final String currency;
  final String timezone;

  factory RestaurantDraft.fromJson(JsonMap json) => RestaurantDraft(
        name: asString(json['name']),
        city: asString(json['city']),
        address: asString(json['address']),
        cuisine: asString(json['cuisine']),
        status: asString(json['status']),
        statusLabel: asString(json['statusLabel']),
        category: asString(json['category']),
        categoryLabel: asString(json['categoryLabel']),
        currency: asString(json['currency']),
        timezone: asString(json['timezone']),
      );

  JsonMap toJson() => {
        'name': name,
        'city': city,
        'address': address,
        'cuisine': cuisine,
        'status': status,
        'statusLabel': statusLabel,
        'category': category,
        'categoryLabel': categoryLabel,
        'currency': currency,
        'timezone': timezone,
      };
}

class NewRestaurantDraft extends RestaurantDraft {
  const NewRestaurantDraft({
    required super.name,
    required super.city,
    required super.address,
    required super.cuisine,
    required super.status,
    required super.statusLabel,
    required super.category,
    required super.categoryLabel,
    required super.currency,
    required super.timezone,
    required this.code,
    required this.imageUrl,
    this.floorsCount,
  });

  final String code;
  final String imageUrl;

  /// Cantidad de pisos del local; se crean como "Piso 1", "Piso 2"… (renombrables después).
  final int? floorsCount;

  factory NewRestaurantDraft.fromJson(JsonMap json) {
    final base = RestaurantDraft.fromJson(json);

    return NewRestaurantDraft(
      name: base.name,
      city: base.city,
      address: base.address,
      cuisine: base.cuisine,
      status: base.status,
      statusLabel: base.statusLabel,
      category: base.category,
      categoryLabel: base.categoryLabel,
      currency: base.currency,
      timezone: base.timezone,
      code: asString(json['code']),
      imageUrl: asString(json['imageUrl']),
      floorsCount: asIntOrNull(json['floorsCount']),
    );
  }

  @override
  JsonMap toJson() => {
        ...super.toJson(),
        'code': code,
        'imageUrl': imageUrl,
        if (floorsCount != null) 'floorsCount': floorsCount,
      };
}

/// Pisos iniciales de una sede nueva.
List<SiteFloor> _initialFloors(num count) {
  final rounded = count.isFinite ? count.round() : 0;
  final total = (rounded == 0 ? 1 : rounded).clamp(1, 10);
  return List.generate(total, (index) => SiteFloor(id: 'piso-${index + 1}', name: 'Piso ${index + 1}'));
}

/// Alta de sede: crea el restaurante y su registro operativo (plano de sala vacío).
Future<RestaurantSite> createRestaurant(NewRestaurantDraft draft) async {
  final restaurantDraft = draft.toJson()..remove('floorsCount');
  final payload = await http('/restaurants', method: 'POST', body: {
    ...restaurantDraft,
    'slug': slugify(draft.name),
    'badgeLabel': draft.categoryLabel,
    'badgeTone': 'blue',
    'capacityLabel': 'Cubiertos: —',
    'roleLabel': 'Dirección de sede',
    'kpis': {
      'revenueLabel': '—',
      'revenueHint': 'Sin datos todavía',
      'marginLabel': '—',
      'stockLabel': '—',
      'stockHint': '—',
      'stockNote': '—',
      'occupancyLabel': '—',
      'occupancyHint': '—',
      'occupancyPercent': 0,
    },
  });

  if (!_isRestaurantSite(payload)) {
    throw HttpError('No se pudo crear la sede.', 500);
  }

  final site = _toRestaurantSite(payload);

  await http('/siteOperations', method: 'POST', body: {
    'restaurantId': site.id,
    'shiftLabel': 'Sin turno configurado',
    'floors': _initialFloors(draft.floorsCount ?? 1).map((floor) => floor.toJson()).toList(),
    'kpis': {
      'revenue': '—',
      'revenueHint': '—',
      'ticket': '—',
      'margin': '—',
      'occupancyCurrent': 0,
      'occupancyMax': 0,
      'occupancyDetail': '—',
      'occupancyVip': '—',
      'cadence': '—',
      'cadenceHint': '—',
      'cadenceDetail': '—',
      'cellar': '—',
      'cellarShare': '—',
      'cellarDetail': '—',
    },
    'tables': <Object>[],
    'staff': <Object>[],
    'quality': {'chef': '—', 'title': '—', 'description': '—', 'imageUrl': '', 'extra': '—'},
    'stations': <Object>[],
    'alerts': <Object>[],
    'cellar': {'sommelier': '—', 'champagnes': 0, 'reds': 0, 'whites': 0, 'pairingPercent': 0},
    'brigade': {'present': 0, 'total': 0, 'kitchen': '—', 'floor': '—', 'support': '—', 'headChef': '—'},
  });

  return site;
}

/// `draft & { imageUrl?: string }`: la imagen opcional va como parámetro con nombre.
Future<RestaurantSite> updateRestaurant(String id, RestaurantDraft draft, {String? imageUrl}) async {
  final payload = await http('/restaurants/$id', method: 'PATCH', body: {
    ...draft.toJson(),
    'imageUrl': ?imageUrl,
  });

  if (!_isRestaurantSite(payload)) {
    throw HttpError('No se pudo actualizar la sede.', 500);
  }

  return _toRestaurantSite(payload);
}

class OrganizationDraft {
  const OrganizationDraft({required this.name, required this.code});

  final String name;
  final String code;

  factory OrganizationDraft.fromJson(JsonMap json) =>
      OrganizationDraft(name: asString(json['name']), code: asString(json['code']));

  JsonMap toJson() => {'name': name, 'code': code};
}

Future<Organization> updateOrganization(String id, OrganizationDraft draft) async {
  final payload = await http('/organizations/$id', method: 'PATCH', body: draft.toJson());

  if (!_isOrganization(payload)) {
    throw HttpError('No se pudo actualizar la organización.', 500);
  }

  return _toOrganization(payload);
}

bool _isLiveTable(Object? value) {
  if (value is! Map) {
    return false;
  }

  return value['number'] is String &&
      value['seats'] is num &&
      value['occupiedSeats'] is num &&
      tableFloorStatuses.contains(value['floorStatus']) &&
      value['guests'] is num &&
      value['tagLabel'] is String &&
      tableTagTones.contains(value['tagTone']) &&
      value['location'] is String &&
      value['staff'] is String &&
      value['statusLabel'] is String &&
      value['courseLabel'] is String &&
      value['dish'] is String &&
      value['note'] is String &&
      value['qrToken'] is String &&
      value['qrActive'] is bool;
}

bool _isSiteStaffMember(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isId(value['id']) &&
      value['name'] is String &&
      value['role'] is String &&
      staffAreas.contains(value['area']) &&
      staffShiftStatuses.contains(value['status']);
}

bool _isSiteOperation(Object? value) {
  if (value is! Map ||
      value['kpis'] is! Map ||
      value['quality'] is! Map ||
      value['cellar'] is! Map ||
      value['brigade'] is! Map) {
    return false;
  }

  final tables = value['tables'];
  final staff = value['staff'];

  return _isId(value['id']) &&
      _isId(value['restaurantId']) &&
      value['shiftLabel'] is String &&
      tables is List &&
      tables.every(_isLiveTable) &&
      staff is List &&
      staff.every(_isSiteStaffMember) &&
      value['stations'] is List &&
      value['alerts'] is List;
}

/// Normaliza pisos y mesas (ver `SiteOperation.fromJson`).
SiteOperation _toSiteOperation(Object? value) => SiteOperation.fromJson(asMap(value));

Future<SiteOperation?> fetchSiteOperation(String restaurantId) async {
  final payload = await http('/siteOperations');

  if (payload is! List) {
    return null;
  }

  for (final item in payload) {
    if (_isSiteOperation(item) && asId((item as Map)['restaurantId']) == restaurantId) {
      return _toSiteOperation(item);
    }
  }

  return null;
}

/// Guarda pisos y mesas juntos (al eliminar un piso, sus mesas pasan a otro).
Future<SiteOperation> updateSiteOperationFloors(String operationId, List<SiteFloor> floors, List<LiveTable> tables) async {
  final payload = await http('/siteOperations/$operationId', method: 'PATCH', body: {
    'floors': floors.map((floor) => floor.toJson()).toList(),
    'tables': tables.map((table) => table.toJson()).toList(),
  });

  if (!_isSiteOperation(payload)) {
    throw HttpError('No se pudieron guardar los pisos.', 500);
  }

  return _toSiteOperation(payload);
}

Future<SiteOperation> updateSiteOperationTables(String operationId, List<LiveTable> tables) async {
  final payload = await http('/siteOperations/$operationId', method: 'PATCH', body: {
    'tables': tables.map((table) => table.toJson()).toList(),
  });

  if (!_isSiteOperation(payload)) {
    throw HttpError('No se pudo actualizar el plano de sala.', 500);
  }

  return _toSiteOperation(payload);
}
