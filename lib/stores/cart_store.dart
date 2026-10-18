import 'package:flutter/foundation.dart';

import '../core/storage/local_storage.dart';
import '../core/utils/json.dart';
import '../core/utils/time.dart';

class CartItem {
  CartItem({required this.productId, required this.name, required this.price, required this.quantity, this.notes = ''});

  final String productId;
  final String name;
  double price;
  int quantity;
  String notes;

  factory CartItem.fromJson(JsonMap json) => CartItem(
        productId: asId(json['productId']),
        name: asString(json['name']),
        price: asDouble(json['price']),
        quantity: asInt(json['quantity'], 1),
        notes: asString(json['notes']),
      );

  JsonMap toJson() => {'productId': productId, 'name': name, 'price': price, 'quantity': quantity, 'notes': notes};
}

const String _cartKey = 'restaurant-cmr:cart';

String _newBatchId() => createId('batch');

/// Carrito del comensal. Se guarda para sobrevivir a cerrar la app.
class CartStore extends ChangeNotifier {
  CartStore() {
    final stored = LocalStorage.readJson(_cartKey);

    if (stored is Map && stored['items'] is List) {
      final json = asMap(stored);
      restaurantId = asStringOrNull(json['restaurantId']);
      items = asMapList(json['items']).map(CartItem.fromJson).toList();
      batchId = asStringOrNull(json['batchId']) ?? _newBatchId();
    } else {
      batchId = _newBatchId();
    }
  }

  String? restaurantId;
  List<CartItem> items = [];

  /// Clave de idempotencia del próximo envío. Se conserva hasta que el envío se confirma.
  late String batchId;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) => sum + item.price * item.quantity);

  CartItem? _find(String productId) {
    for (final item in items) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  int quantityOf(String productId) => _find(productId)?.quantity ?? 0;

  void ensureRestaurant(String nextRestaurantId) {
    if (restaurantId != nextRestaurantId) {
      restaurantId = nextRestaurantId;
      items = [];
      _changed();
    }
  }

  void addItem({required String productId, required String name, required double price, int quantity = 1}) {
    final existing = _find(productId);

    if (existing != null) {
      existing.quantity += quantity;
    } else {
      items = [...items, CartItem(productId: productId, name: name, price: price, quantity: quantity)];
    }

    _changed();
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    _find(productId)?.quantity = quantity;
    _changed();
  }

  void setNotes(String productId, String notes) {
    _find(productId)?.notes = notes;
    _changed();
  }

  void removeItem(String productId) {
    items = items.where((item) => item.productId != productId).toList();
    _changed();
  }

  void setPrice(String productId, double price) {
    _find(productId)?.price = price;
    _changed();
  }

  /// Vacía el carrito tras un envío confirmado y prepara una clave nueva para el próximo.
  void clear() {
    items = [];
    batchId = _newBatchId();
    _changed();
  }

  void _changed() {
    LocalStorage.writeJson(_cartKey, {
      'restaurantId': restaurantId,
      'items': items.map((item) => item.toJson()).toList(),
      'batchId': batchId,
    });
    notifyListeners();
  }
}
