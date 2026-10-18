import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/string.dart';
import 'types.dart';

bool _isId(Object? value) => value is String || value is num;

const List<MenuStatus> _menuStatuses = ['draft', 'active', 'inactive'];

bool _isMenuStatus(Object? value) => value is String && _menuStatuses.contains(value);

bool _isMenu(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isId(value['id']) && _isId(value['restaurantId']) && value['name'] is String && _isMenuStatus(value['status']);
}

Menu _toMenu(Object? value) => Menu.fromJson(asMap(value));

bool _isMenuCategory(Object? value) {
  if (value is! Map) {
    return false;
  }

  return _isId(value['id']) &&
      _isId(value['restaurantId']) &&
      _isId(value['menuId']) &&
      value['name'] is String &&
      value['description'] is String &&
      value['position'] is num;
}

bool _isMenuProduct(Object? value) {
  if (value is! Map) {
    return false;
  }

  final tags = value['tags'];
  final allergens = value['allergens'];

  return _isId(value['id']) &&
      _isId(value['restaurantId']) &&
      _isId(value['categoryId']) &&
      value['name'] is String &&
      value['description'] is String &&
      value['price'] is num &&
      value['imageUrl'] is String &&
      value['isAvailable'] is bool &&
      tags is List &&
      tags.every((tag) => tag is String) &&
      allergens is List &&
      allergens.every((allergen) => allergen is String);
}

MenuCategory _toMenuCategory(Object? value) => MenuCategory.fromJson(asMap(value));

/// Normaliza el producto (ver `MenuProduct.fromJson`).
MenuProduct _toMenuProduct(Object? value) => MenuProduct.fromJson(asMap(value));

/// Equivalente aproximado a `localeCompare` en español: compara sin tildes ni mayúsculas.
int _compareNames(String a, String b) => normalizeSearch(a).compareTo(normalizeSearch(b));

int _compareProducts(MenuProduct a, MenuProduct b) {
  final byPosition = a.position.compareTo(b.position);
  return byPosition != 0 ? byPosition : _compareNames(a.name, b.name);
}

Future<List<Menu>> fetchMenus(String restaurantId) async {
  final payload = await http('/menus');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isMenu).map(_toMenu).where((menu) => menu.restaurantId == restaurantId).toList();
}

Future<Menu?> fetchActiveMenu(String restaurantId) async {
  final menus = await fetchMenus(restaurantId);

  for (final menu in menus) {
    if (menu.status == 'active') return menu;
  }

  return null;
}

Future<Menu> createMenu(String restaurantId, String name) async {
  final payload = await http('/menus', method: 'POST', body: {'restaurantId': restaurantId, 'name': name, 'status': 'draft'});

  if (!_isMenu(payload)) {
    throw HttpError('No se pudo crear el menú.', 500);
  }

  return _toMenu(payload);
}

Future<Menu> _patchMenuStatus(String id, MenuStatus status) async {
  final payload = await http('/menus/$id', method: 'PATCH', body: {'status': status});

  if (!_isMenu(payload)) {
    throw HttpError('No se pudo actualizar el estado del menú.', 500);
  }

  return _toMenu(payload);
}

/// Cambia el estado de un menú. Solo puede haber un menú activo por sede:
/// al activar uno, el que estaba activo pasa a inactivo. Devuelve los menús afectados.
Future<List<Menu>> updateMenuStatus(Menu menu, MenuStatus status) async {
  final changed = <Menu>[];

  if (status == 'active') {
    final others = (await fetchMenus(menu.restaurantId)).where((item) => item.id != menu.id && item.status == 'active');

    for (final other in others) {
      changed.add(await _patchMenuStatus(other.id, 'inactive'));
    }
  }

  changed.add(await _patchMenuStatus(menu.id, status));
  return changed;
}

Future<List<MenuCategory>> fetchMenuCategories(String restaurantId) async {
  final payload = await http('/menuCategories');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isMenuCategory).map(_toMenuCategory).where((category) => category.restaurantId == restaurantId).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
}

Future<List<MenuCategory>> fetchActiveMenuCategories(String restaurantId) async {
  final activeMenu = await fetchActiveMenu(restaurantId);

  if (activeMenu == null) {
    return [];
  }

  final categories = await fetchMenuCategories(restaurantId);
  return categories.where((category) => category.menuId == activeMenu.id).toList();
}

Future<List<MenuProduct>> fetchMenuProducts(String restaurantId) async {
  final payload = await http('/menuProducts');

  if (payload is! List) {
    return [];
  }

  return payload.where(_isMenuProduct).map(_toMenuProduct).where((product) => product.restaurantId == restaurantId).toList()
    ..sort(_compareProducts);
}

/// Carta que ve el comensal: categorías del menú activo y solo productos activos.
Future<({List<MenuCategory> categories, List<MenuProduct> products})> fetchCustomerMenu(String restaurantId) async {
  final (categories, products) = await (fetchActiveMenuCategories(restaurantId), fetchMenuProducts(restaurantId)).wait;
  final categoryIds = categories.map((category) => category.id).toSet();

  return (
    categories: categories,
    products: products.where((product) => product.isActive && categoryIds.contains(product.categoryId)).toList(),
  );
}

Future<List<MenuCategory>> reorderMenuCategories(List<MenuCategory> categories) async {
  final updated = <MenuCategory>[];

  for (final (index, category) in categories.indexed) {
    final position = index + 1;

    if (category.position == position) {
      updated.add(category);
      continue;
    }

    final payload = await http('/menuCategories/${category.id}', method: 'PATCH', body: {'position': position});
    updated.add(_isMenuCategory(payload) ? _toMenuCategory(payload) : category.copyWith(position: position));
  }

  return updated;
}

Future<List<MenuProduct>> reorderMenuProducts(List<MenuProduct> products) async {
  final updated = <MenuProduct>[];

  for (final (index, product) in products.indexed) {
    final position = index + 1;

    if (product.position == position) {
      updated.add(product);
      continue;
    }

    updated.add(await patchMenuProduct(product.id, {'position': position}));
  }

  return updated;
}

Future<MenuCategory> createMenuCategory(String restaurantId, String menuId, MenuCategoryDraft draft, int position) async {
  final payload = await http('/menuCategories', method: 'POST', body: {
    'restaurantId': restaurantId,
    'menuId': menuId,
    'position': position,
    ...draft.toJson(),
  });

  if (!_isMenuCategory(payload)) {
    throw HttpError('No se pudo crear la categoría.', 500);
  }

  return _toMenuCategory(payload);
}

Future<MenuCategory> updateMenuCategory(String id, MenuCategoryDraft draft) async {
  final payload = await http('/menuCategories/$id', method: 'PATCH', body: draft.toJson());

  if (!_isMenuCategory(payload)) {
    throw HttpError('No se pudo actualizar la categoría.', 500);
  }

  return _toMenuCategory(payload);
}

Future<void> deleteMenuCategory(String id) async {
  await http('/menuCategories/$id', method: 'DELETE');
}

/// Texto de búsqueda sin tildes que se guarda junto al producto. json-server solo
/// compara en minúsculas; con este campo "jamon" encuentra "Jamón". En el backend
/// real esto lo resolverá la base de datos (p. ej. unaccent + ILIKE en Postgres).
String _productSearchText(MenuProductDraft draft) {
  return normalizeSearch([draft.name, draft.description, ...draft.tags, ...draft.ingredients].join(' '));
}

/// Sugerencias para el buscador predictivo de la carta del comensal.
/// Contrato pensado para el backend: GET /restaurants/:id/menu/suggestions?q=…&limit=…
Future<List<MenuProduct>> searchMenuSuggestions(String restaurantId, String query, [int limit = 6]) async {
  final term = normalizeSearch(query);

  if (term.isEmpty) {
    return [];
  }

  final where = {
    'restaurantId': {'eq': restaurantId},
    'isActive': {'eq': true},
    'searchText': {'contains': term},
  };
  final payload = await http('/menuProducts?_where=${encodeQuery(jsonEncode(where))}');

  if (payload is! List) {
    return [];
  }

  final products = payload.where(_isMenuProduct).map(_toMenuProduct).toList();

  /* Primero los que empiezan por el término, luego los que lo contienen en el nombre, luego el resto. */
  int rank(MenuProduct product) {
    final name = normalizeSearch(product.name);
    return name.startsWith(term) ? 0 : (name.contains(term) ? 1 : 2);
  }

  products.sort((a, b) {
    final byRank = rank(a) - rank(b);
    return byRank != 0 ? byRank : _compareNames(a.name, b.name);
  });

  return products.take(limit).toList();
}

Future<MenuProduct> createMenuProduct(String restaurantId, MenuProductDraft draft, [int position = 0]) async {
  final payload = await http('/menuProducts', method: 'POST', body: {
    'restaurantId': restaurantId,
    'position': position,
    ...draft.toJson(),
    'searchText': _productSearchText(draft),
    'imageUrl': draft.imageUrl.isNotEmpty
        ? draft.imageUrl
        : 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=640&h=480&fit=crop&auto=format&q=70',
  });

  if (!_isMenuProduct(payload)) {
    throw HttpError('No se pudo crear el producto.', 500);
  }

  return _toMenuProduct(payload);
}

/// Cambios parciales (`Partial<MenuProductDraft & { position, searchText }>`) como mapa JSON.
Future<MenuProduct> patchMenuProduct(String id, JsonMap changes) async {
  final payload = await http('/menuProducts/$id', method: 'PATCH', body: changes);

  if (!_isMenuProduct(payload)) {
    throw HttpError('No se pudo actualizar el producto.', 500);
  }

  return _toMenuProduct(payload);
}

Future<MenuProduct> updateMenuProduct(String id, MenuProductDraft draft) {
  return patchMenuProduct(id, {...draft.toJson(), 'searchText': _productSearchText(draft)});
}

/// Convierte una imagen elegida por el usuario (sus bytes) en un data URL reducido, para
/// guardarla directamente en db.json mientras no haya almacenamiento de archivos.
/// Sin codificador JPEG en el SDK, se guarda como PNG.
Future<String> imageFileToDataUrl(Uint8List file, [int maxSize = 640]) async {
  final ui.ImageDescriptor descriptor;

  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(file);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
  } catch (_) {
    throw HttpError('El archivo no es una imagen válida.', 0);
  }

  final scale = math.min(1.0, maxSize / math.max(descriptor.width, descriptor.height));
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);

  if (data == null) {
    throw HttpError('No se pudo leer la imagen.', 0);
  }

  return 'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
}

Future<void> deleteMenuProduct(String id) async {
  await http('/menuProducts/$id', method: 'DELETE');
}
