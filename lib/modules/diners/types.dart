import '../../core/utils/json.dart';

/// Perfil del cliente (comensal). Independiente del perfil del personal del restaurante.
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.birthday,
    required this.dietaryPreferences,
    required this.allergens,
    required this.marketingOptIn,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;

  /// Fecha YYYY-MM-DD, opcional.
  final String? birthday;

  /// Ej: Vegetariano, Sin gluten. Sirve para recomendar platos más adelante.
  final List<String> dietaryPreferences;

  /// Alergias declaradas; la carta podrá avisar de los productos que las contienen.
  final List<String> allergens;

  /// Acepta recibir promociones y novedades.
  final bool marketingOptIn;
  final String? createdAt;

  /// Aplica la normalización de `toProfile` (textos vacíos → null, listas solo de textos).
  factory CustomerProfile.fromJson(JsonMap json) {
    final phone = json['phone'];
    final birthday = json['birthday'];

    return CustomerProfile(
      id: asId(json['id']),
      name: asString(json['name']),
      email: asString(json['email']),
      phone: phone is String && phone.isNotEmpty ? phone : null,
      birthday: birthday is String && birthday.isNotEmpty ? birthday : null,
      dietaryPreferences: asList(json['dietaryPreferences']).whereType<String>().toList(),
      allergens: asList(json['allergens']).whereType<String>().toList(),
      marketingOptIn: json['marketingOptIn'] == true,
      createdAt: json['createdAt'] is String ? json['createdAt'] as String : null,
    );
  }

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'birthday': birthday,
        'dietaryPreferences': dietaryPreferences,
        'allergens': allergens,
        'marketingOptIn': marketingOptIn,
        'createdAt': createdAt,
      };

  CustomerProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? birthday,
    List<String>? dietaryPreferences,
    List<String>? allergens,
    bool? marketingOptIn,
    String? createdAt,
  }) =>
      CustomerProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        birthday: birthday ?? this.birthday,
        dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
        allergens: allergens ?? this.allergens,
        marketingOptIn: marketingOptIn ?? this.marketingOptIn,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// `Pick<CustomerProfile, 'name' | 'phone' | 'birthday' | 'dietaryPreferences' | 'allergens' | 'marketingOptIn'>`
class CustomerProfileDraft {
  const CustomerProfileDraft({
    required this.name,
    this.phone,
    this.birthday,
    required this.dietaryPreferences,
    required this.allergens,
    required this.marketingOptIn,
  });

  final String name;
  final String? phone;
  final String? birthday;
  final List<String> dietaryPreferences;
  final List<String> allergens;
  final bool marketingOptIn;

  factory CustomerProfileDraft.fromJson(JsonMap json) => CustomerProfileDraft(
        name: asString(json['name']),
        phone: asStringOrNull(json['phone']),
        birthday: asStringOrNull(json['birthday']),
        dietaryPreferences: asStringList(json['dietaryPreferences']),
        allergens: asStringList(json['allergens']),
        marketingOptIn: asBool(json['marketingOptIn']),
      );

  /// Borrador editable a partir del perfil guardado.
  factory CustomerProfileDraft.fromProfile(CustomerProfile profile) => CustomerProfileDraft(
        name: profile.name,
        phone: profile.phone,
        birthday: profile.birthday,
        dietaryPreferences: profile.dietaryPreferences,
        allergens: profile.allergens,
        marketingOptIn: profile.marketingOptIn,
      );

  JsonMap toJson() => {
        'name': name,
        'phone': phone,
        'birthday': birthday,
        'dietaryPreferences': dietaryPreferences,
        'allergens': allergens,
        'marketingOptIn': marketingOptIn,
      };

  CustomerProfileDraft copyWith({
    String? name,
    String? phone,
    String? birthday,
    List<String>? dietaryPreferences,
    List<String>? allergens,
    bool? marketingOptIn,
  }) =>
      CustomerProfileDraft(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        birthday: birthday ?? this.birthday,
        dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
        allergens: allergens ?? this.allergens,
        marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      );
}

// ignore: constant_identifier_names
const List<String> DIETARY_PREFERENCES = ['Vegetariano', 'Vegano', 'Sin gluten', 'Sin lactosa', 'Halal', 'Kosher'];

// ignore: constant_identifier_names
const List<String> ALLERGEN_OPTIONS = [
  'Gluten',
  'Lácteos',
  'Huevo',
  'Frutos secos',
  'Marisco',
  'Pescado',
  'Soja',
  'Sésamo',
];
