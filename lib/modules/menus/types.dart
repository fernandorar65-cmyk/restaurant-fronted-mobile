import '../../core/utils/json.dart';

/// 'draft' | 'active' | 'inactive'
typedef MenuStatus = String;

class Menu {
  const Menu({required this.id, required this.restaurantId, required this.name, required this.status});

  final String id;
  final String restaurantId;
  final String name;
  final MenuStatus status;

  factory Menu.fromJson(JsonMap json) => Menu(
        id: asId(json['id']),
        restaurantId: asId(json['restaurantId']),
        name: asString(json['name']),
        status: asString(json['status']),
      );

  JsonMap toJson() => {'id': id, 'restaurantId': restaurantId, 'name': name, 'status': status};

  Menu copyWith({String? id, String? restaurantId, String? name, MenuStatus? status}) => Menu(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        name: name ?? this.name,
        status: status ?? this.status,
      );
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.menuId,
    required this.name,
    required this.description,
    required this.position,
  });

  final String id;
  final String restaurantId;
  final String menuId;
  final String name;
  final String description;
  final int position;

  factory MenuCategory.fromJson(JsonMap json) => MenuCategory(
        id: asId(json['id']),
        restaurantId: asId(json['restaurantId']),
        menuId: asId(json['menuId']),
        name: asString(json['name']),
        description: asString(json['description']),
        position: asInt(json['position']),
      );

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'menuId': menuId,
        'name': name,
        'description': description,
        'position': position,
      };

  MenuCategory copyWith({
    String? id,
    String? restaurantId,
    String? menuId,
    String? name,
    String? description,
    int? position,
  }) =>
      MenuCategory(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        menuId: menuId ?? this.menuId,
        name: name ?? this.name,
        description: description ?? this.description,
        position: position ?? this.position,
      );
}

class MenuProduct {
  const MenuProduct({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    required this.isAvailable,
    required this.position,
    required this.tags,
    required this.allergens,
    required this.ingredients,
    required this.portion,
    required this.presentation,
    required this.longDescription,
    this.prepMinutes,
  });

  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  /// Se muestra en la carta. Un producto inactivo no aparece para el comensal.
  final bool isActive;

  /// Se puede pedir. Un producto activo pero no disponible se muestra como "Agotado".
  final bool isAvailable;
  final int position;
  final List<String> tags;
  final List<String> allergens;

  /// Ingredientes principales, en el orden en que se quieren mostrar.
  final List<String> ingredients;

  /// Tamaño de la porción: "6 unidades", "Para compartir · 400 g". Vacío = no se muestra.
  final String portion;

  /// Cómo llega a la mesa (emplatado, acompañamientos, recomendaciones). Vacío = no se muestra.
  final String presentation;

  /// Texto largo para el detalle del plato; la descripción corta queda para la tarjeta de la carta.
  final String longDescription;

  /// Tiempo aproximado de preparación en minutos. null = no se muestra.
  final int? prepMinutes;

  /// Aplica los valores por defecto de `toMenuProduct` (activo, posición 0, textos vacíos…).
  factory MenuProduct.fromJson(JsonMap json) {
    final prepMinutes = json['prepMinutes'];

    return MenuProduct(
      id: asId(json['id']),
      restaurantId: asId(json['restaurantId']),
      categoryId: asId(json['categoryId']),
      name: asString(json['name']),
      description: asString(json['description']),
      price: asDouble(json['price']),
      imageUrl: asString(json['imageUrl']),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      isAvailable: asBool(json['isAvailable']),
      position: json['position'] is num ? (json['position'] as num).round() : 0,
      tags: asList(json['tags']).whereType<String>().toList(),
      allergens: asList(json['allergens']).whereType<String>().toList(),
      ingredients: asList(json['ingredients']).whereType<String>().toList(),
      portion: json['portion'] is String ? json['portion'] as String : '',
      presentation: json['presentation'] is String ? json['presentation'] as String : '',
      longDescription: json['longDescription'] is String ? json['longDescription'] as String : '',
      prepMinutes: prepMinutes is num && prepMinutes > 0 ? prepMinutes.round() : null,
    );
  }

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'isAvailable': isAvailable,
        'position': position,
        'tags': tags,
        'allergens': allergens,
        'ingredients': ingredients,
        'portion': portion,
        'presentation': presentation,
        'longDescription': longDescription,
        'prepMinutes': prepMinutes,
      };

  /// `prepMinutes` admite null explícito: se usa `clearPrepMinutes` para quitarlo.
  MenuProduct copyWith({
    String? id,
    String? restaurantId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isActive,
    bool? isAvailable,
    int? position,
    List<String>? tags,
    List<String>? allergens,
    List<String>? ingredients,
    String? portion,
    String? presentation,
    String? longDescription,
    int? prepMinutes,
    bool clearPrepMinutes = false,
  }) =>
      MenuProduct(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
        isAvailable: isAvailable ?? this.isAvailable,
        position: position ?? this.position,
        tags: tags ?? this.tags,
        allergens: allergens ?? this.allergens,
        ingredients: ingredients ?? this.ingredients,
        portion: portion ?? this.portion,
        presentation: presentation ?? this.presentation,
        longDescription: longDescription ?? this.longDescription,
        prepMinutes: clearPrepMinutes ? null : (prepMinutes ?? this.prepMinutes),
      );
}

class MenuCategoryDraft {
  const MenuCategoryDraft({required this.name, required this.description});

  final String name;
  final String description;

  factory MenuCategoryDraft.fromJson(JsonMap json) =>
      MenuCategoryDraft(name: asString(json['name']), description: asString(json['description']));

  JsonMap toJson() => {'name': name, 'description': description};
}

class MenuProductDraft {
  const MenuProductDraft({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    required this.isAvailable,
    required this.tags,
    required this.allergens,
    required this.ingredients,
    required this.portion,
    required this.presentation,
    required this.longDescription,
    this.prepMinutes,
  });

  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isActive;
  final bool isAvailable;
  final List<String> tags;
  final List<String> allergens;
  final List<String> ingredients;
  final String portion;
  final String presentation;
  final String longDescription;
  final int? prepMinutes;

  factory MenuProductDraft.fromJson(JsonMap json) => MenuProductDraft(
        categoryId: asId(json['categoryId']),
        name: asString(json['name']),
        description: asString(json['description']),
        price: asDouble(json['price']),
        imageUrl: asString(json['imageUrl']),
        isActive: asBool(json['isActive'], true),
        isAvailable: asBool(json['isAvailable'], true),
        tags: asStringList(json['tags']),
        allergens: asStringList(json['allergens']),
        ingredients: asStringList(json['ingredients']),
        portion: asString(json['portion']),
        presentation: asString(json['presentation']),
        longDescription: asString(json['longDescription']),
        prepMinutes: asIntOrNull(json['prepMinutes']),
      );

  JsonMap toJson() => {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'isAvailable': isAvailable,
        'tags': tags,
        'allergens': allergens,
        'ingredients': ingredients,
        'portion': portion,
        'presentation': presentation,
        'longDescription': longDescription,
        'prepMinutes': prepMinutes,
      };
}
