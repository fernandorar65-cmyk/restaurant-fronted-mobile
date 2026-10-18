import '../../core/utils/json.dart';
import '../../core/utils/string.dart';

/// Resumen mínimo de una sede (equivalente a `RestaurantSummary` de src/types).
class RestaurantSummary {
  const RestaurantSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory RestaurantSummary.fromJson(JsonMap json) => RestaurantSummary(id: asId(json['id']), name: asString(json['name']));

  JsonMap toJson() => {'id': id, 'name': name};
}

/// 'fine-dining' | 'bistro' | 'lab'
typedef RestaurantCategory = String;

/// 'active' | 'inactive' | 'suspended'
typedef RestaurantOperationalStatus = String;

/// 'amber' | 'emerald' | 'wine' | 'blue'
typedef RestaurantBadgeTone = String;

class Organization {
  const Organization({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  factory Organization.fromJson(JsonMap json) =>
      Organization(id: asId(json['id']), name: asString(json['name']), code: asString(json['code']));

  JsonMap toJson() => {'id': id, 'name': name, 'code': code};

  Organization copyWith({String? id, String? name, String? code}) =>
      Organization(id: id ?? this.id, name: name ?? this.name, code: code ?? this.code);
}

class RestaurantKpis {
  const RestaurantKpis({
    required this.revenueLabel,
    required this.revenueHint,
    required this.marginLabel,
    required this.stockLabel,
    required this.stockHint,
    required this.stockNote,
    required this.occupancyLabel,
    required this.occupancyHint,
    required this.occupancyPercent,
  });

  final String revenueLabel;
  final String revenueHint;
  final String marginLabel;
  final String stockLabel;
  final String stockHint;
  final String stockNote;
  final String occupancyLabel;
  final String occupancyHint;
  final double occupancyPercent;

  factory RestaurantKpis.fromJson(JsonMap json) => RestaurantKpis(
        revenueLabel: asString(json['revenueLabel']),
        revenueHint: asString(json['revenueHint']),
        marginLabel: asString(json['marginLabel']),
        stockLabel: asString(json['stockLabel']),
        stockHint: asString(json['stockHint']),
        stockNote: asString(json['stockNote']),
        occupancyLabel: asString(json['occupancyLabel']),
        occupancyHint: asString(json['occupancyHint']),
        occupancyPercent: asDouble(json['occupancyPercent']),
      );

  JsonMap toJson() => {
        'revenueLabel': revenueLabel,
        'revenueHint': revenueHint,
        'marginLabel': marginLabel,
        'stockLabel': stockLabel,
        'stockHint': stockHint,
        'stockNote': stockNote,
        'occupancyLabel': occupancyLabel,
        'occupancyHint': occupancyHint,
        'occupancyPercent': occupancyPercent,
      };
}

/// Cómo puede pedir el comensal en esta sede y condiciones del delivery.
class SiteFulfillment {
  const SiteFulfillment({
    required this.dineIn,
    required this.pickup,
    required this.delivery,
    required this.deliveryRadiusKm,
    required this.deliveryFee,
    required this.minOrder,
  });

  final bool dineIn;

  /// Pedido anticipado: lo deja listo para cuando llegue (comer allí o para llevar).
  final bool pickup;
  final bool delivery;
  final double deliveryRadiusKm;
  final double deliveryFee;

  /// Importe mínimo del pedido para delivery. 0 = sin mínimo.
  final double minOrder;

  /// Sin configuración guardada, la sede solo atiende en mesa (comportamiento previo).
  factory SiteFulfillment.fromJson(Object? value) {
    final record = asMap(value);
    double number(String key) => record[key] is num ? (record[key] as num).toDouble() : 0;

    return SiteFulfillment(
      dineIn: record['dineIn'] != false,
      pickup: record['pickup'] == true,
      delivery: record['delivery'] == true,
      deliveryRadiusKm: number('deliveryRadiusKm'),
      deliveryFee: number('deliveryFee'),
      minOrder: number('minOrder'),
    );
  }

  JsonMap toJson() => {
        'dineIn': dineIn,
        'pickup': pickup,
        'delivery': delivery,
        'deliveryRadiusKm': deliveryRadiusKm,
        'deliveryFee': deliveryFee,
        'minOrder': minOrder,
      };

  SiteFulfillment copyWith({
    bool? dineIn,
    bool? pickup,
    bool? delivery,
    double? deliveryRadiusKm,
    double? deliveryFee,
    double? minOrder,
  }) =>
      SiteFulfillment(
        dineIn: dineIn ?? this.dineIn,
        pickup: pickup ?? this.pickup,
        delivery: delivery ?? this.delivery,
        deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
        deliveryFee: deliveryFee ?? this.deliveryFee,
        minOrder: minOrder ?? this.minOrder,
      );
}

class RestaurantSite {
  const RestaurantSite({
    required this.id,
    required this.code,
    required this.slug,
    required this.name,
    required this.city,
    required this.address,
    required this.imageUrl,
    required this.category,
    required this.categoryLabel,
    required this.cuisine,
    required this.status,
    required this.statusLabel,
    required this.badgeLabel,
    required this.badgeTone,
    required this.capacityLabel,
    required this.roleLabel,
    required this.kpis,
    required this.currency,
    required this.timezone,
    this.lat,
    this.lng,
    required this.fulfillment,
  });

  final String id;
  final String code;

  /// Identificador legible para la URL pública de la sede (/l-etoile-atelier/menu).
  final String slug;
  final String name;
  final String city;
  final String address;
  final String imageUrl;
  final RestaurantCategory category;
  final String categoryLabel;
  final String cuisine;
  final RestaurantOperationalStatus status;
  final String statusLabel;
  final String badgeLabel;
  final RestaurantBadgeTone badgeTone;
  final String capacityLabel;
  final String roleLabel;
  final RestaurantKpis kpis;

  /// Código ISO 4217 (EUR, PEN, USD…).
  final String currency;

  /// Zona horaria IANA (Europe/Madrid, America/Lima…).
  final String timezone;

  /// Ubicación para el mapa del comensal; sin coordenadas la sede no aparece en el mapa.
  final double? lat;
  final double? lng;
  final SiteFulfillment fulfillment;

  /// Aplica los mismos valores por defecto que `toRestaurantSite` (slug, moneda, zona, fulfillment).
  factory RestaurantSite.fromJson(JsonMap json) {
    final name = asString(json['name']);
    final slug = asString(json['slug']);
    final currency = asString(json['currency']);
    final timezone = asString(json['timezone']);

    return RestaurantSite(
      id: asId(json['id']),
      code: asString(json['code']),
      slug: slug.isNotEmpty ? slug : slugify(name),
      name: name,
      city: asString(json['city']),
      address: asString(json['address']),
      imageUrl: asString(json['imageUrl']),
      category: asString(json['category']),
      categoryLabel: asString(json['categoryLabel']),
      cuisine: asString(json['cuisine']),
      status: asString(json['status']),
      statusLabel: asString(json['statusLabel']),
      badgeLabel: asString(json['badgeLabel']),
      badgeTone: asString(json['badgeTone']),
      capacityLabel: asString(json['capacityLabel']),
      roleLabel: asString(json['roleLabel']),
      kpis: RestaurantKpis.fromJson(asMap(json['kpis'])),
      currency: currency.isNotEmpty ? currency : 'EUR',
      timezone: timezone.isNotEmpty ? timezone : 'Europe/Madrid',
      lat: json['lat'] is num ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] is num ? (json['lng'] as num).toDouble() : null,
      fulfillment: SiteFulfillment.fromJson(json['fulfillment']),
    );
  }

  JsonMap toJson() => {
        'id': id,
        'code': code,
        'slug': slug,
        'name': name,
        'city': city,
        'address': address,
        'imageUrl': imageUrl,
        'category': category,
        'categoryLabel': categoryLabel,
        'cuisine': cuisine,
        'status': status,
        'statusLabel': statusLabel,
        'badgeLabel': badgeLabel,
        'badgeTone': badgeTone,
        'capacityLabel': capacityLabel,
        'roleLabel': roleLabel,
        'kpis': kpis.toJson(),
        'currency': currency,
        'timezone': timezone,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'fulfillment': fulfillment.toJson(),
      };

  RestaurantSite copyWith({
    String? id,
    String? code,
    String? slug,
    String? name,
    String? city,
    String? address,
    String? imageUrl,
    RestaurantCategory? category,
    String? categoryLabel,
    String? cuisine,
    RestaurantOperationalStatus? status,
    String? statusLabel,
    String? badgeLabel,
    RestaurantBadgeTone? badgeTone,
    String? capacityLabel,
    String? roleLabel,
    RestaurantKpis? kpis,
    String? currency,
    String? timezone,
    double? lat,
    double? lng,
    SiteFulfillment? fulfillment,
  }) =>
      RestaurantSite(
        id: id ?? this.id,
        code: code ?? this.code,
        slug: slug ?? this.slug,
        name: name ?? this.name,
        city: city ?? this.city,
        address: address ?? this.address,
        imageUrl: imageUrl ?? this.imageUrl,
        category: category ?? this.category,
        categoryLabel: categoryLabel ?? this.categoryLabel,
        cuisine: cuisine ?? this.cuisine,
        status: status ?? this.status,
        statusLabel: statusLabel ?? this.statusLabel,
        badgeLabel: badgeLabel ?? this.badgeLabel,
        badgeTone: badgeTone ?? this.badgeTone,
        capacityLabel: capacityLabel ?? this.capacityLabel,
        roleLabel: roleLabel ?? this.roleLabel,
        kpis: kpis ?? this.kpis,
        currency: currency ?? this.currency,
        timezone: timezone ?? this.timezone,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        fulfillment: fulfillment ?? this.fulfillment,
      );
}

/// 'critical' | 'neutral' | 'alert'
typedef TableTagTone = String;

/// 'occupied' | 'available' | 'reserved' | 'cleaning'
typedef TableFloorStatus = String;

/// Estado operativo de la mesa: solo una mesa `active` puede abrir una atención.
/// 'active' | 'inactive' | 'maintenance'
typedef TableStatus = String;

/// 'kitchen' | 'floor' | 'support'
typedef StaffArea = String;

/// 'on-shift' | 'break' | 'absent'
typedef StaffShiftStatus = String;

/// Piso o planta de una sede (planta baja, primer piso, terraza…).
class SiteFloor {
  const SiteFloor({required this.id, required this.name});

  final String id;
  final String name;

  factory SiteFloor.fromJson(JsonMap json) => SiteFloor(id: asId(json['id']), name: asString(json['name']));

  JsonMap toJson() => {'id': id, 'name': name};

  SiteFloor copyWith({String? id, String? name}) => SiteFloor(id: id ?? this.id, name: name ?? this.name);
}

class LiveTable {
  const LiveTable({
    required this.number,
    required this.floorId,
    required this.code,
    required this.status,
    required this.seats,
    required this.occupiedSeats,
    required this.floorStatus,
    required this.guests,
    required this.tagLabel,
    required this.tagTone,
    required this.location,
    required this.staff,
    required this.statusLabel,
    required this.courseLabel,
    required this.dish,
    required this.note,
    required this.qrToken,
    required this.qrActive,
  });

  final String number;

  /// Piso donde está la mesa (id de SiteFloor).
  final String floorId;
  final String code;
  final TableStatus status;
  final int seats;
  final int occupiedSeats;
  final TableFloorStatus floorStatus;
  final int guests;
  final String tagLabel;
  final TableTagTone tagTone;
  final String location;
  final String staff;
  final String statusLabel;
  final String courseLabel;
  final String dish;
  final String note;
  final String qrToken;
  final bool qrActive;

  /// Aplica los valores por defecto de `toLiveTable` (código `M-<número>` y estado `active`).
  factory LiveTable.fromJson(JsonMap json) {
    final number = asString(json['number']);
    final code = asString(json['code']);
    final status = json['status'];

    return LiveTable(
      number: number,
      floorId: asString(json['floorId']),
      code: code.isNotEmpty ? code : 'M-$number',
      status: tableStatuses.contains(status) ? status as String : 'active',
      seats: asInt(json['seats']),
      occupiedSeats: asInt(json['occupiedSeats']),
      floorStatus: asString(json['floorStatus']),
      guests: asInt(json['guests']),
      tagLabel: asString(json['tagLabel']),
      tagTone: asString(json['tagTone']),
      location: asString(json['location']),
      staff: asString(json['staff']),
      statusLabel: asString(json['statusLabel']),
      courseLabel: asString(json['courseLabel']),
      dish: asString(json['dish']),
      note: asString(json['note']),
      qrToken: asString(json['qrToken']),
      qrActive: asBool(json['qrActive']),
    );
  }

  JsonMap toJson() => {
        'number': number,
        'floorId': floorId,
        'code': code,
        'status': status,
        'seats': seats,
        'occupiedSeats': occupiedSeats,
        'floorStatus': floorStatus,
        'guests': guests,
        'tagLabel': tagLabel,
        'tagTone': tagTone,
        'location': location,
        'staff': staff,
        'statusLabel': statusLabel,
        'courseLabel': courseLabel,
        'dish': dish,
        'note': note,
        'qrToken': qrToken,
        'qrActive': qrActive,
      };

  LiveTable copyWith({
    String? number,
    String? floorId,
    String? code,
    TableStatus? status,
    int? seats,
    int? occupiedSeats,
    TableFloorStatus? floorStatus,
    int? guests,
    String? tagLabel,
    TableTagTone? tagTone,
    String? location,
    String? staff,
    String? statusLabel,
    String? courseLabel,
    String? dish,
    String? note,
    String? qrToken,
    bool? qrActive,
  }) =>
      LiveTable(
        number: number ?? this.number,
        floorId: floorId ?? this.floorId,
        code: code ?? this.code,
        status: status ?? this.status,
        seats: seats ?? this.seats,
        occupiedSeats: occupiedSeats ?? this.occupiedSeats,
        floorStatus: floorStatus ?? this.floorStatus,
        guests: guests ?? this.guests,
        tagLabel: tagLabel ?? this.tagLabel,
        tagTone: tagTone ?? this.tagTone,
        location: location ?? this.location,
        staff: staff ?? this.staff,
        statusLabel: statusLabel ?? this.statusLabel,
        courseLabel: courseLabel ?? this.courseLabel,
        dish: dish ?? this.dish,
        note: note ?? this.note,
        qrToken: qrToken ?? this.qrToken,
        qrActive: qrActive ?? this.qrActive,
      );
}

/// Valores válidos de los estados de mesa y personal (para validar el JSON).
const List<TableFloorStatus> tableFloorStatuses = ['occupied', 'available', 'reserved', 'cleaning'];
const List<TableStatus> tableStatuses = ['active', 'inactive', 'maintenance'];
const List<TableTagTone> tableTagTones = ['critical', 'neutral', 'alert'];
const List<StaffArea> staffAreas = ['kitchen', 'floor', 'support'];
const List<StaffShiftStatus> staffShiftStatuses = ['on-shift', 'break', 'absent'];

class SiteStaffMember {
  const SiteStaffMember({required this.id, required this.name, required this.role, required this.area, required this.status});

  final String id;
  final String name;
  final String role;
  final StaffArea area;
  final StaffShiftStatus status;

  factory SiteStaffMember.fromJson(JsonMap json) => SiteStaffMember(
        id: asId(json['id']),
        name: asString(json['name']),
        role: asString(json['role']),
        area: asString(json['area']),
        status: asString(json['status']),
      );

  JsonMap toJson() => {'id': id, 'name': name, 'role': role, 'area': area, 'status': status};

  SiteStaffMember copyWith({String? id, String? name, String? role, StaffArea? area, StaffShiftStatus? status}) =>
      SiteStaffMember(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        area: area ?? this.area,
        status: status ?? this.status,
      );
}

class KitchenStation {
  const KitchenStation({
    required this.name,
    required this.chef,
    required this.progressLabel,
    required this.progressPercent,
    required this.detail,
  });

  final String name;
  final String chef;
  final String progressLabel;
  final double progressPercent;
  final String detail;

  factory KitchenStation.fromJson(JsonMap json) => KitchenStation(
        name: asString(json['name']),
        chef: asString(json['chef']),
        progressLabel: asString(json['progressLabel']),
        progressPercent: asDouble(json['progressPercent']),
        detail: asString(json['detail']),
      );

  JsonMap toJson() =>
      {'name': name, 'chef': chef, 'progressLabel': progressLabel, 'progressPercent': progressPercent, 'detail': detail};
}

class SiteAlert {
  const SiteAlert({required this.title, required this.status, required this.description});

  final String title;
  final String status;
  final String description;

  factory SiteAlert.fromJson(JsonMap json) =>
      SiteAlert(title: asString(json['title']), status: asString(json['status']), description: asString(json['description']));

  JsonMap toJson() => {'title': title, 'status': status, 'description': description};
}

/// `SiteOperation['kpis']`.
class SiteOperationKpis {
  const SiteOperationKpis({
    required this.revenue,
    required this.revenueHint,
    required this.ticket,
    required this.margin,
    required this.occupancyCurrent,
    required this.occupancyMax,
    required this.occupancyDetail,
    required this.occupancyVip,
    required this.cadence,
    required this.cadenceHint,
    required this.cadenceDetail,
    required this.cellar,
    required this.cellarShare,
    required this.cellarDetail,
  });

  final String revenue;
  final String revenueHint;
  final String ticket;
  final String margin;
  final int occupancyCurrent;
  final int occupancyMax;
  final String occupancyDetail;
  final String occupancyVip;
  final String cadence;
  final String cadenceHint;
  final String cadenceDetail;
  final String cellar;
  final String cellarShare;
  final String cellarDetail;

  factory SiteOperationKpis.fromJson(JsonMap json) => SiteOperationKpis(
        revenue: asString(json['revenue']),
        revenueHint: asString(json['revenueHint']),
        ticket: asString(json['ticket']),
        margin: asString(json['margin']),
        occupancyCurrent: asInt(json['occupancyCurrent']),
        occupancyMax: asInt(json['occupancyMax']),
        occupancyDetail: asString(json['occupancyDetail']),
        occupancyVip: asString(json['occupancyVip']),
        cadence: asString(json['cadence']),
        cadenceHint: asString(json['cadenceHint']),
        cadenceDetail: asString(json['cadenceDetail']),
        cellar: asString(json['cellar']),
        cellarShare: asString(json['cellarShare']),
        cellarDetail: asString(json['cellarDetail']),
      );

  JsonMap toJson() => {
        'revenue': revenue,
        'revenueHint': revenueHint,
        'ticket': ticket,
        'margin': margin,
        'occupancyCurrent': occupancyCurrent,
        'occupancyMax': occupancyMax,
        'occupancyDetail': occupancyDetail,
        'occupancyVip': occupancyVip,
        'cadence': cadence,
        'cadenceHint': cadenceHint,
        'cadenceDetail': cadenceDetail,
        'cellar': cellar,
        'cellarShare': cellarShare,
        'cellarDetail': cellarDetail,
      };
}

/// `SiteOperation['quality']`.
class SiteOperationQuality {
  const SiteOperationQuality({
    required this.chef,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.extra,
  });

  final String chef;
  final String title;
  final String description;
  final String imageUrl;
  final String extra;

  factory SiteOperationQuality.fromJson(JsonMap json) => SiteOperationQuality(
        chef: asString(json['chef']),
        title: asString(json['title']),
        description: asString(json['description']),
        imageUrl: asString(json['imageUrl']),
        extra: asString(json['extra']),
      );

  JsonMap toJson() => {'chef': chef, 'title': title, 'description': description, 'imageUrl': imageUrl, 'extra': extra};
}

/// `SiteOperation['cellar']`.
class SiteOperationCellar {
  const SiteOperationCellar({
    required this.sommelier,
    required this.champagnes,
    required this.reds,
    required this.whites,
    required this.pairingPercent,
  });

  final String sommelier;
  final int champagnes;
  final int reds;
  final int whites;
  final double pairingPercent;

  factory SiteOperationCellar.fromJson(JsonMap json) => SiteOperationCellar(
        sommelier: asString(json['sommelier']),
        champagnes: asInt(json['champagnes']),
        reds: asInt(json['reds']),
        whites: asInt(json['whites']),
        pairingPercent: asDouble(json['pairingPercent']),
      );

  JsonMap toJson() =>
      {'sommelier': sommelier, 'champagnes': champagnes, 'reds': reds, 'whites': whites, 'pairingPercent': pairingPercent};
}

/// `SiteOperation['brigade']`.
class SiteOperationBrigade {
  const SiteOperationBrigade({
    required this.present,
    required this.total,
    required this.kitchen,
    required this.floor,
    required this.support,
    required this.headChef,
  });

  final int present;
  final int total;
  final String kitchen;
  final String floor;
  final String support;
  final String headChef;

  factory SiteOperationBrigade.fromJson(JsonMap json) => SiteOperationBrigade(
        present: asInt(json['present']),
        total: asInt(json['total']),
        kitchen: asString(json['kitchen']),
        floor: asString(json['floor']),
        support: asString(json['support']),
        headChef: asString(json['headChef']),
      );

  JsonMap toJson() =>
      {'present': present, 'total': total, 'kitchen': kitchen, 'floor': floor, 'support': support, 'headChef': headChef};
}

/// Sin pisos guardados, la sede tiene una sola planta.
const SiteFloor defaultFloor = SiteFloor(id: 'planta-baja', name: 'Planta baja');

List<SiteFloor> _toFloors(Object? value) {
  final floors = asMapList(value)
      .where((item) => item['id'] is String && item['name'] is String)
      .map((item) => SiteFloor(id: item['id'] as String, name: item['name'] as String))
      .toList();
  return floors.isNotEmpty ? floors : const [defaultFloor];
}

class SiteOperation {
  const SiteOperation({
    required this.id,
    required this.restaurantId,
    required this.shiftLabel,
    required this.kpis,
    required this.floors,
    required this.tables,
    required this.staff,
    required this.quality,
    required this.stations,
    required this.alerts,
    required this.cellar,
    required this.brigade,
  });

  final String id;
  final String restaurantId;
  final String shiftLabel;
  final SiteOperationKpis kpis;

  /// Pisos de la sede, en orden. Siempre hay al menos uno.
  final List<SiteFloor> floors;
  final List<LiveTable> tables;
  final List<SiteStaffMember> staff;
  final SiteOperationQuality quality;
  final List<KitchenStation> stations;
  final List<SiteAlert> alerts;
  final SiteOperationCellar cellar;
  final SiteOperationBrigade brigade;

  /// Aplica la normalización de `toSiteOperation` (pisos por defecto y mesas sin piso válido).
  factory SiteOperation.fromJson(JsonMap json) {
    final floors = _toFloors(json['floors']);
    final floorIds = floors.map((floor) => floor.id).toSet();

    return SiteOperation(
      id: asId(json['id']),
      restaurantId: asId(json['restaurantId']),
      shiftLabel: asString(json['shiftLabel']),
      kpis: SiteOperationKpis.fromJson(asMap(json['kpis'])),
      floors: floors,
      // Una mesa sin piso (o con un piso que ya no existe) queda en el primero.
      tables: asMapList(json['tables'])
          .map(LiveTable.fromJson)
          .map((table) => floorIds.contains(table.floorId) ? table : table.copyWith(floorId: floors.first.id))
          .toList(),
      staff: asMapList(json['staff']).map(SiteStaffMember.fromJson).toList(),
      quality: SiteOperationQuality.fromJson(asMap(json['quality'])),
      stations: asMapList(json['stations']).map(KitchenStation.fromJson).toList(),
      alerts: asMapList(json['alerts']).map(SiteAlert.fromJson).toList(),
      cellar: SiteOperationCellar.fromJson(asMap(json['cellar'])),
      brigade: SiteOperationBrigade.fromJson(asMap(json['brigade'])),
    );
  }

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'shiftLabel': shiftLabel,
        'kpis': kpis.toJson(),
        'floors': floors.map((floor) => floor.toJson()).toList(),
        'tables': tables.map((table) => table.toJson()).toList(),
        'staff': staff.map((member) => member.toJson()).toList(),
        'quality': quality.toJson(),
        'stations': stations.map((station) => station.toJson()).toList(),
        'alerts': alerts.map((alert) => alert.toJson()).toList(),
        'cellar': cellar.toJson(),
        'brigade': brigade.toJson(),
      };

  SiteOperation copyWith({
    String? id,
    String? restaurantId,
    String? shiftLabel,
    SiteOperationKpis? kpis,
    List<SiteFloor>? floors,
    List<LiveTable>? tables,
    List<SiteStaffMember>? staff,
    SiteOperationQuality? quality,
    List<KitchenStation>? stations,
    List<SiteAlert>? alerts,
    SiteOperationCellar? cellar,
    SiteOperationBrigade? brigade,
  }) =>
      SiteOperation(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        shiftLabel: shiftLabel ?? this.shiftLabel,
        kpis: kpis ?? this.kpis,
        floors: floors ?? this.floors,
        tables: tables ?? this.tables,
        staff: staff ?? this.staff,
        quality: quality ?? this.quality,
        stations: stations ?? this.stations,
        alerts: alerts ?? this.alerts,
        cellar: cellar ?? this.cellar,
        brigade: brigade ?? this.brigade,
      );
}
