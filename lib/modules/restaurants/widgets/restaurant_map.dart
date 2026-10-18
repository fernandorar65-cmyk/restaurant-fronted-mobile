import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../types.dart';

/// Punto del mapa (lat/lng).
typedef MapPoint = ({double lat, double lng});

/// Zoom de calle: se distinguen avenidas y cuadras alrededor del comensal.
const double _userZoom = 15;

/// Sedes a esta distancia o menos se incluyen en el encuadre al ubicar al comensal.
const double _nearbyKm = 3;

const Distance _distance = Distance();

/// Mapa de sedes (OpenStreetMap) con pines por nombre y la ubicación del comensal.
class RestaurantMap extends StatefulWidget {
  const RestaurantMap({super.key, required this.restaurants, required this.selectedId, required this.userLocation, required this.onSelect});

  final List<RestaurantSite> restaurants;
  final String? selectedId;
  final MapPoint? userLocation;
  final ValueChanged<String> onSelect;

  @override
  State<RestaurantMap> createState() => _RestaurantMapState();
}

class _RestaurantMapState extends State<RestaurantMap> with TickerProviderStateMixin {
  final MapController _map = MapController();
  bool _ready = false;
  AnimationController? _flight;

  @override
  void didUpdateWidget(covariant RestaurantMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;

    final userChanged = oldWidget.userLocation != widget.userLocation;

    if (userChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.userLocation != null ? _focusUser() : _fitAll());
    } else if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flyToSelected());
    } else if (!_sameIds(oldWidget.restaurants, widget.restaurants) && widget.userLocation == null) {
      // Con la ubicación del comensal, filtrar no debe alejar el mapa de su zona.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }
  }

  @override
  void dispose() {
    _flight?.dispose();
    _map.dispose();
    super.dispose();
  }

  bool _sameIds(List<RestaurantSite> a, List<RestaurantSite> b) =>
      a.length == b.length && Iterable.generate(a.length).every((index) => a[index].id == b[index].id);

  List<RestaurantSite> get _located => widget.restaurants.where((site) => site.lat != null && site.lng != null).toList();

  LatLng _point(RestaurantSite site) => LatLng(site.lat!, site.lng!);

  /// Encuadra todas las sedes.
  void _fitAll() {
    if (!mounted) return;
    final points = _located.map(_point).toList();

    if (points.length == 1) {
      _flyTo(points.first, 14);
    } else if (points.length > 1) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(70, 80, 70, 40),
          maxZoom: 14,
        ),
      );
    }
  }

  /// Acerca el mapa al comensal. Si hay sedes a pocos km, las encuadra junto a él.
  void _focusUser() {
    final user = widget.userLocation;
    if (!mounted || user == null) return;

    final here = LatLng(user.lat, user.lng);
    final nearby = _located.map(_point).where((point) => _distance.as(LengthUnit.Meter, here, point) <= _nearbyKm * 1000).toList();

    if (nearby.isEmpty) {
      _flyTo(here, _userZoom);
      return;
    }

    // Márgenes amplios: arriba está el buscador y abajo el botón "Cerca de mí".
    final fit = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([here, ...nearby]),
      padding: const EdgeInsets.fromLTRB(90, 110, 90, 100),
      maxZoom: 16,
    ).fit(_map.camera);
    _flyTo(fit.center, fit.zoom);
  }

  void _flyToSelected() {
    for (final site in _located) {
      if (site.id == widget.selectedId) {
        _flyTo(_point(site), math.max(_map.camera.zoom, 13));
        return;
      }
    }
  }

  /// Movimiento animado del mapa (equivale a `flyTo` de Leaflet).
  void _flyTo(LatLng target, double zoom) {
    if (!mounted) return;
    _flight?.dispose();
    final from = _map.camera;
    final latTween = Tween(begin: from.center.latitude, end: target.latitude);
    final lngTween = Tween(begin: from.center.longitude, end: target.longitude);
    final zoomTween = Tween(begin: from.zoom, end: zoom);
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    _flight = controller;

    controller.addListener(() {
      _map.move(LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)), zoomTween.evaluate(curve));
    });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final located = _located;
    final user = widget.userLocation;

    return Semantics(
      label: 'Mapa de restaurantes',
      container: true,
      child: ColoredBox(
        color: c.surfaceContainer,
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(40.4168, -3.7038),
            initialZoom: 6,
            onMapReady: () {
              _ready = true;
              if (widget.userLocation != null) {
                _focusUser();
              } else {
                _fitAll();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.restaurantcmr.restaurant_fronted_mobile',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                // El seleccionado va al final para quedar por encima.
                for (final site in [
                  ...located.where((site) => site.id != widget.selectedId),
                  ...located.where((site) => site.id == widget.selectedId),
                ])
                  Marker(
                    point: _point(site),
                    width: 200,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: _RestaurantPin(
                      name: site.name,
                      selected: site.id == widget.selectedId,
                      onTap: () => widget.onSelect(site.id),
                    ),
                  ),
                if (user != null) Marker(point: LatLng(user.lat, user.lng), width: 40, height: 40, child: const _UserDot()),
              ],
            ),
            const SimpleAttributionWidget(source: Text('OpenStreetMap'), alignment: Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}

/// Pin con el nombre de la sede; el seleccionado se destaca en color primario.
class _RestaurantPin extends StatelessWidget {
  const _RestaurantPin({required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final background = selected ? c.primary : c.surfaceContainerLowest;
    final foreground = selected ? c.onPrimary : c.onSurface;

    return Semantics(
      button: true,
      label: name,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                  border: selected ? null : Border.all(color: c.outlineVariant),
                  boxShadow: [
                    const BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                    if (selected) BoxShadow(color: c.primary.withValues(alpha: 0.25), spreadRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_rounded, size: 14, color: foreground),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.label(fontSize: 12, color: foreground)),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -5),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(width: 10, height: 10, color: background),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatefulWidget {
  const _UserDot();

  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Container(
            width: 20 + 20 * _controller.value,
            height: 20 + 20 * _controller.value,
            decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.4 * (1 - _controller.value)), shape: BoxShape.circle),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: c.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
