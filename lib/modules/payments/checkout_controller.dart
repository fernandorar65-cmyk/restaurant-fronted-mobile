import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../stores/cart_store.dart';
import '../../stores/checkout_store.dart';
import '../../stores/diner_store.dart';
import '../menus/api.dart';
import '../menus/types.dart';
import '../restaurants/api.dart';
import '../restaurants/types.dart';
import 'checkout.dart';

/// Margen sobre el plato más lento, para emplatar y despachar.
const int _readyBufferMin = 10;

/// Si no hay tiempos cargados en los platos.
const int _defaultPrepMin = 20;

final RegExp _phonePattern = RegExp(r'^[+\d][\d\s-]{6,}$');

/// Punto geográfico (`{ lat, lng }` en la web).
typedef GeoPoint = ({double lat, double lng});

/// Distancia en km entre dos puntos (haversine).
double distanceKm(GeoPoint a, GeoPoint b) {
  double toRad(double deg) => (deg * math.pi) / 180;
  final dLat = toRad(b.lat - a.lat);
  final dLng = toRad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(toRad(a.lat)) * math.cos(toRad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 6371 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

String _toTimeValue(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// 5.0 → "5", 2.5 → "2.5" (como imprime los números la web).
String _formatNumber(num value) => value == value.roundToDouble() ? value.round().toString() : value.toString();

/// Estado compartido por las pantallas del checkout: sede, totales, hora estimada
/// y validación de los datos de entrega según la modalidad elegida.
///
/// Carga la sede al crearse (equivale al `onMounted` de la web) y reenvía los cambios
/// de los stores, así la vista solo escucha al controlador. Llamar a [dispose] al salir.
class CheckoutController extends ChangeNotifier {
  CheckoutController({required this.diner, required this.cart, required this.checkout}) {
    diner.addListener(notifyListeners);
    cart.addListener(notifyListeners);
    checkout.addListener(notifyListeners);
    // Fuera del build: `load` modifica el CheckoutStore.
    scheduleMicrotask(load);
  }

  final DinerStore diner;
  final CartStore cart;
  final CheckoutStore checkout;

  RestaurantSite? site;
  List<MenuProduct> products = [];
  bool isLoading = true;
  bool loadError = false;
  bool _disposed = false;

  /// Modalidades que ofrece la sede.
  List<FulfillmentMode> get availableModes {
    final options = site?.fulfillment;

    if (options == null) {
      return [];
    }

    return [
      if (options.dineIn) 'dine-in',
      if (options.pickup) 'pickup',
      if (options.delivery) 'delivery',
    ];
  }

  double get subtotal => cart.subtotal;

  double get deliveryFee => checkout.mode == 'delivery' ? (site?.fulfillment.deliveryFee ?? 0).toDouble() : 0;

  double get total => subtotal + deliveryFee;

  /// Minutos hasta que el pedido esté listo: el plato más lento del carrito más un margen.
  int get prepMinutes {
    final times = <num>[];

    for (final item in cart.items) {
      final value = products.where((product) => product.id == item.productId).firstOrNull?.prepMinutes;

      if (value != null) {
        times.add(value);
      }
    }

    return (times.isNotEmpty ? times.reduce(math.max).round() : _defaultPrepMin) + _readyBufferMin;
  }

  /// Horarios de llegada de hoy, cada 15 minutos desde que el pedido puede estar listo y durante 3 horas.
  List<String> get arrivalSlots {
    final now = DateTime.now();
    final base = now.add(Duration(minutes: prepMinutes));
    final earliest = DateTime(base.year, base.month, base.day, base.hour, (base.minute / 15).ceil() * 15);

    return List.generate(12, (index) => earliest.add(Duration(minutes: index * 15)))
        .where((slot) => slot.day == now.day)
        .map(_toTimeValue)
        .toList();
  }

  /// Distancia del punto de entrega a la sede, si el comensal compartió su ubicación.
  double? get deliveryDistanceKm {
    final lat = checkout.delivery.lat;
    final lng = checkout.delivery.lng;
    final siteLat = site?.lat;
    final siteLng = site?.lng;

    if (lat == null || lng == null || siteLat == null || siteLng == null) {
      return null;
    }

    return distanceKm((lat: lat, lng: lng), (lat: siteLat.toDouble(), lng: siteLng.toDouble()));
  }

  /// Primer problema que impide continuar al pago, o null si todo está completo.
  String? get fulfillmentError {
    final mode = checkout.mode;
    final options = site?.fulfillment;

    if (mode == null || options == null) {
      return 'Elige cómo quieres recibir tu pedido.';
    }

    if (!availableModes.contains(mode)) {
      return 'Esta sede no ofrece esa modalidad.';
    }

    if (mode == 'dine-in') {
      final code = diner.tableCode;
      return code != null && code.isNotEmpty ? null : 'Ingresa el código de tu mesa.';
    }

    if (checkout.contact.name.trim().isEmpty) {
      return 'Ingresa tu nombre.';
    }

    if (!_phonePattern.hasMatch(checkout.contact.phone.trim())) {
      return 'Ingresa un teléfono válido para avisarte.';
    }

    if (mode == 'pickup') {
      return arrivalSlots.contains(checkout.pickup.arrivalTime) ? null : 'Elige a qué hora llegarás.';
    }

    if (checkout.delivery.address.trim().isEmpty) {
      return 'Ingresa la dirección de entrega.';
    }

    if (options.minOrder > 0 && subtotal < options.minOrder) {
      return 'El pedido no llega al mínimo para delivery.';
    }

    final distance = deliveryDistanceKm;

    if (distance != null && distance > options.deliveryRadiusKm) {
      return 'Tu ubicación está fuera del radio de entrega (${_formatNumber(options.deliveryRadiusKm)} km).';
    }

    return null;
  }

  Future<void> load() async {
    if (_disposed) return;

    final restaurantId = diner.restaurantId;
    isLoading = true;
    loadError = false;
    notifyListeners();

    if (restaurantId == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    checkout.ensureRestaurant(restaurantId);

    final customer = diner.customer;

    if (checkout.contact.name.isEmpty && customer != null) {
      checkout.contact.name = customer.name;
      checkout.save();
    }

    try {
      final (loadedSite, loadedProducts) = await (fetchRestaurantById(restaurantId), fetchMenuProducts(restaurantId)).wait;
      site = loadedSite;
      products = loadedProducts;
    } catch (_) {
      loadError = true;
    } finally {
      isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Vuelve a cargar la sede y la carta (botón "Reintentar").
  Future<void> reload() => load();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    diner.removeListener(notifyListeners);
    cart.removeListener(notifyListeners);
    checkout.removeListener(notifyListeners);
    super.dispose();
  }
}
