import 'package:flutter/foundation.dart';

import '../core/storage/local_storage.dart';
import '../core/utils/json.dart';
import '../modules/payments/checkout.dart';

const String _checkoutKey = 'restaurant-cmr:checkout';

class CheckoutContact {
  CheckoutContact({this.name = '', this.phone = ''});

  String name;
  String phone;

  JsonMap toJson() => {'name': name, 'phone': phone};
}

class PickupDetails {
  PickupDetails({this.arrivalTime = '', this.eatIn = true});

  /// Hora de llegada "HH:MM" del día de hoy.
  String arrivalTime;

  /// true = come en el local al llegar; false = para llevar.
  bool eatIn;

  JsonMap toJson() => {'arrivalTime': arrivalTime, 'eatIn': eatIn};
}

class DeliveryDetails {
  DeliveryDetails({this.address = '', this.reference = '', this.lat, this.lng});

  String address;
  String reference;

  /// Ubicación compartida para validar el radio de entrega (opcional).
  double? lat;
  double? lng;

  JsonMap toJson() => {'address': address, 'reference': reference, 'lat': lat, 'lng': lng};
}

class CheckoutReceiptItem {
  const CheckoutReceiptItem({required this.name, required this.quantity, required this.price});

  final String name;
  final int quantity;
  final double price;
}

/// Comprobante del último pago (simulado) para la pantalla de resultado. Solo en memoria.
class CheckoutReceipt {
  const CheckoutReceipt({
    required this.code,
    required this.restaurantName,
    required this.mode,
    required this.fulfillmentDetail,
    required this.methodLabel,
    required this.paymentDetail,
    required this.items,
    required this.deliveryFee,
    required this.total,
    required this.currency,
    required this.readyAt,
    required this.createdAt,
  });

  final String code;
  final String restaurantName;
  final FulfillmentMode mode;
  final String fulfillmentDetail;
  final String methodLabel;
  final String paymentDetail;
  final List<CheckoutReceiptItem> items;
  final double deliveryFee;
  final double total;
  final String currency;

  /// Hora estimada (HH:MM) en que estará listo o llegará.
  final String readyAt;
  final String createdAt;
}

/// Borrador del checkout del comensal: cómo recibe el pedido, sus datos y el método
/// de pago elegido. Se guarda para no perderlo al cerrar la app o volver atrás.
/// Tras modificar `contact`, `pickup` o `delivery` directamente, llamar a [save].
class CheckoutStore extends ChangeNotifier {
  CheckoutStore() {
    final stored = LocalStorage.readJson(_checkoutKey);

    if (stored is Map) {
      final json = asMap(stored);
      final contactJson = asMap(json['contact']);
      final pickupJson = asMap(json['pickup']);
      final deliveryJson = asMap(json['delivery']);
      restaurantId = asStringOrNull(json['restaurantId']);
      mode = asStringOrNull(json['mode']);
      contact = CheckoutContact(name: asString(contactJson['name']), phone: asString(contactJson['phone']));
      pickup = PickupDetails(arrivalTime: asString(pickupJson['arrivalTime']), eatIn: asBool(pickupJson['eatIn'], true));
      delivery = DeliveryDetails(
        address: asString(deliveryJson['address']),
        reference: asString(deliveryJson['reference']),
        lat: asDoubleOrNull(deliveryJson['lat']),
        lng: asDoubleOrNull(deliveryJson['lng']),
      );
      method = isCheckoutMethod(json['method']) ? json['method'] as String : null;
    }
  }

  String? restaurantId;
  FulfillmentMode? mode;
  CheckoutContact contact = CheckoutContact();
  PickupDetails pickup = PickupDetails();
  DeliveryDetails delivery = DeliveryDetails();
  CheckoutMethod? method;
  CheckoutReceipt? lastReceipt;

  /// Un borrador de otra sede no sirve: modo, horario y dirección dependen de la sede.
  void ensureRestaurant(String nextRestaurantId) {
    if (restaurantId != nextRestaurantId) {
      restaurantId = nextRestaurantId;
      mode = null;
      pickup = PickupDetails();
      delivery = DeliveryDetails();
      method = null;
      save();
    }
  }

  void setMode(FulfillmentMode? next) {
    mode = next;
    save();
  }

  void setMethod(CheckoutMethod? next) {
    method = next;
    save();
  }

  void setReceipt(CheckoutReceipt? receipt) {
    lastReceipt = receipt;
    notifyListeners();
  }

  void reset() {
    restaurantId = null;
    mode = null;
    pickup = PickupDetails();
    delivery = DeliveryDetails();
    method = null;
    save();
  }

  /// Persiste el borrador y avisa a la UI.
  void save() {
    LocalStorage.writeJson(_checkoutKey, {
      'restaurantId': restaurantId,
      'mode': mode,
      'contact': contact.toJson(),
      'pickup': pickup.toJson(),
      'delivery': delivery.toJson(),
      'method': method,
    });
    notifyListeners();
  }
}
