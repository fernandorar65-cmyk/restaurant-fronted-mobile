import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/string.dart';
import '../../../router/routes.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/diner_notice.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/restaurant_map.dart';
import 'qr_scanner_view.dart';

/// Distancia en km entre dos puntos (fórmula de haversine).
double _distanceKm(MapPoint from, MapPoint to) {
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(to.lat - from.lat);
  final dLng = toRad(to.lng - from.lng);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(toRad(from.lat)) * math.cos(toRad(to.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

final NumberFormat _kmFormat = NumberFormat('#,##0.#', 'es');
final NumberFormat _bigKmFormat = NumberFormat('#,##0', 'es');

String _formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${(km < 100 ? _kmFormat : _bigKmFormat).format(km)} km';
}

/// "hace 5 minutos", "hace 2 horas", "ayer"… (equivale a `Intl.RelativeTimeFormat` con numeric: 'auto').
String _formatVisitedAt(String iso) {
  final visited = DateTime.tryParse(iso);
  if (visited == null) return '';
  final minutes = DateTime.now().difference(visited).inSeconds / 60;

  String unit(int value, String singular, String plural) => value == 1 ? singular : plural;

  if (minutes.abs() < 60) {
    final value = minutes.round();
    if (value == 0) return 'ahora';
    return 'hace $value ${unit(value, 'minuto', 'minutos')}';
  }

  final hours = (minutes / 60).round();
  if (hours.abs() < 24) {
    return 'hace $hours ${unit(hours, 'hora', 'horas')}';
  }

  final days = (hours / 24).round();
  if (days == 1) return 'ayer';
  if (days == 2) return 'anteayer';
  return 'hace $days días';
}

/// Inicio del comensal: buscar una sede en el mapa o la lista, escanear el QR de la mesa
/// o volver a una sede reciente.
class RestaurantSelectView extends StatefulWidget {
  const RestaurantSelectView({super.key});

  @override
  State<RestaurantSelectView> createState() => _RestaurantSelectViewState();
}

class _RestaurantSelectViewState extends State<RestaurantSelectView> {
  final TextEditingController _search = TextEditingController();
  final Map<String, GlobalKey> _itemKeys = {};

  List<RestaurantSite> _restaurants = [];
  bool _hasLoadError = false;
  bool _isLoading = true;
  String? _category;
  String? _selectedId;

  MapPoint? _userLocation;
  bool _locating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadRestaurants();
    _locateIfGranted();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Las sedes inactivas o suspendidas no se muestran al comensal.
  List<RestaurantSite> get _openRestaurants => _restaurants.where(isRestaurantOpen).toList();

  List<String> get _categories {
    final seen = <String>{};
    return [
      for (final site in _openRestaurants)
        if (seen.add(site.categoryLabel)) site.categoryLabel,
    ];
  }

  double? _distanceTo(RestaurantSite site) {
    final user = _userLocation;
    if (user == null || site.lat == null || site.lng == null) return null;
    return _distanceKm(user, (lat: site.lat!, lng: site.lng!));
  }

  /// Resultado de la búsqueda: filtra por texto y tipo; ordena por cercanía si hay ubicación.
  List<({RestaurantSite site, double? distance})> get _results {
    final query = normalizeSearch(_search.text);

    final filtered = _openRestaurants.where((site) {
      if (_category != null && site.categoryLabel != _category) return false;
      if (query.isEmpty) return true;
      return [site.name, site.city, site.cuisine, site.address, site.categoryLabel].any((field) => normalizeSearch(field).contains(query));
    });

    return filtered.map((site) => (site: site, distance: _distanceTo(site))).toList()
      ..sort((a, b) {
        if (a.distance != null && b.distance != null) return a.distance!.compareTo(b.distance!);
        return normalizeSearch(a.site.name).compareTo(normalizeSearch(b.site.name));
      });
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
    });

    try {
      final list = await fetchRestaurants();
      if (mounted) setState(() => _restaurants = list);
    } catch (_) {
      if (mounted) setState(() => _hasLoadError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Si ya dio permiso antes, se ubica sin volver a preguntar.
  Future<void> _locateIfGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        await _locate();
      }
    } catch (_) {
      // Sin servicio de ubicación: se espera a que pulse "Cerca de mí".
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationError = 'La ubicación del teléfono está desactivada. Puedes buscar por ciudad o nombre.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationError = 'No diste permiso de ubicación. Puedes buscar por ciudad o nombre.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );

      if (mounted) {
        setState(() {
          _userLocation = (lat: position.latitude, lng: position.longitude);
          _selectedId = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationError = 'No pudimos obtener tu ubicación. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _selectFromMap(String id) {
    setState(() => _selectedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemContext = _itemKeys[id]?.currentContext;
      if (itemContext != null) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _browseMenu(RestaurantSite restaurant) {
    final diner = context.read<DinerStore>();

    if (!(diner.isReadyToOrder && diner.restaurantId == restaurant.id)) {
      diner.browse(restaurantId: restaurant.id, restaurantSlug: restaurant.slug, restaurantName: restaurant.name, currency: restaurant.currency);
    }

    context.go(Routes.menu(restaurant.slug));
  }

  void _openScanner() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (context) => const QrScannerView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();
    final results = _results;
    final open = _openRestaurants;
    final categories = _categories;
    final recents = [
      for (final recent in diner.recentRestaurants)
        for (final site in open.where((item) => item.id == recent.id)) (site: site, visitedAt: recent.visitedAt),
    ];

    for (final item in results) {
      _itemKeys.putIfAbsent(item.site.id, GlobalKey.new);
    }

    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          if (diner.customer != null) ...[
            Text(
              'Hola, ${diner.customer!.name.split(' ').first} 👋',
              style: AppFonts.label(fontSize: 15, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
          ],
          const HeadingText('¿Dónde comemos ', accent: 'hoy?', fontSize: 36, height: 1.05),
          const SizedBox(height: 8),
          Text('Encuentra una sede cerca y mira su carta.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (diner.isReadyToOrder) ...[
            _ContinueCard(
              title: '${diner.restaurantName ?? ''} · Mesa ${diner.tableNumber}',
              onTap: () => context.go(diner.attentionId != null ? Routes.orderStatus(diner.attentionId!) : diner.menuRoute),
            ),
            const SizedBox(height: 16),
          ],
          _ScanQrButton(onTap: _openScanner),
          const SizedBox(height: 20),

          // Mapa con buscador flotante.
          Container(
            height: 352,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: RestaurantMap(
                    restaurants: results.map((item) => item.site).toList(),
                    selectedId: _selectedId,
                    userLocation: _userLocation,
                    onSelect: _selectFromMap,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    color: c.surfaceContainerLowest.withValues(alpha: 0.95),
                    elevation: 3,
                    shadowColor: Colors.black26,
                    shape: const StadiumBorder(),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: 14, color: c.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Busca por nombre, ciudad o cocina',
                        prefixIcon: Icon(Icons.search_rounded, color: c.outline),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar búsqueda',
                                icon: Icon(Icons.close_rounded, color: c.outline),
                                onPressed: _search.clear,
                              ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: c.primaryInk, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Material(
                    color: c.surfaceContainerLowest,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    shape: StadiumBorder(side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5))),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _locating ? null : _locate,
                      child: Opacity(
                        opacity: _locating ? 0.6 : 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_locating)
                                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.primaryInk))
                                else
                                  Icon(Icons.my_location_rounded, size: 16, color: c.primaryInk),
                                const SizedBox(width: 8),
                                Text(
                                  _locating ? 'Buscando…' : (_userLocation != null ? 'Actualizar ubicación' : 'Cerca de mí'),
                                  style: AppFonts.label(fontSize: 14, color: c.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_locationError != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(_locationError!, style: TextStyle(fontSize: 14, color: c.onWarningContainer)),
              ),
            ),
          ],

          // Filtro por tipo de local.
          if (categories.length > 1) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final option in <String?>[null, ...categories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: option ?? 'Todos',
                        selected: _category == option,
                        onTap: () => setState(() => _category = option),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Resultados.
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: HeadingText(_userLocation != null ? 'Cerca de ti' : 'Restaurantes'),
              ),
              if (!_isLoading && !_hasLoadError)
                Text(
                  '${results.length} ${results.length == 1 ? 'sede' : 'sedes'}',
                  style: AppFonts.label(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const SkeletonBlock(rows: 3)
          else if (_hasLoadError)
            DinerNotice(kind: 'connection', onRetry: _loadRestaurants)
          else if (results.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
              child: Text(
                open.isEmpty ? 'No hay sedes disponibles en este momento.' : 'No encontramos sedes con esa búsqueda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
            )
          else
            for (final item in results)
              Padding(
                key: _itemKeys[item.site.id],
                padding: const EdgeInsets.only(bottom: 12),
                child: _ResultCard(
                  site: item.site,
                  distance: item.distance,
                  selected: _selectedId == item.site.id,
                  onTap: () => setState(() => _selectedId = item.site.id),
                  onMenu: () => _browseMenu(item.site),
                ),
              ),

          // Recientes.
          const SizedBox(height: 24),
          const HeadingText('Recientes'),
          const SizedBox(height: 12),
          if (recents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: c.outlineVariant)),
              child: Text(
                'Aquí verás las sedes que visites o cuya carta consultes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (final (index, recent) in recents.indexed) ...[
                      if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
                      InkWell(
                        onTap: () => _browseMenu(recent.site),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                _SiteImage(url: recent.site.imageUrl, size: 44, radius: 8),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recent.site.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                                      ),
                                      Text(
                                        '${recent.site.city} · ${_formatVisitedAt(recent.visitedAt)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: c.outline),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('¿Trabajas en un restaurante?', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.primaryInk),
                onPressed: () => context.push(Routes.login),
                child: const Text('Acceso del personal', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SiteImage extends StatelessWidget {
  const _SiteImage({required this.url, required this.size, this.radius = 12});

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = Container(
      width: size,
      height: size,
      color: c.surfaceContainer,
      alignment: Alignment.center,
      child: Icon(Icons.storefront_outlined, color: c.outline),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => fallback),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.deep,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CONTINUAR EN TU MESA', style: AppFonts.eyebrow(color: c.deepAccent)),
                      const SizedBox(height: 4),
                      Text(title, style: AppFonts.headline(fontSize: 17, color: c.onDeep)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, size: 20, color: c.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Acción destacada: abrir la cámara para escanear el QR de la mesa.
class _ScanQrButton extends StatelessWidget {
  const _ScanQrButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: c.primaryInk, width: 1.5)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.qr_code_scanner_rounded, color: c.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Escanear QR de la mesa', style: AppFonts.label(fontSize: 16, color: c.onSurface)),
                    const SizedBox(height: 2),
                    Text('¿Ya estás en el local? Pide desde tu mesa.', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.primaryInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.primary : c.surfaceContainerLowest,
        shape: StadiumBorder(side: selected ? BorderSide.none : BorderSide(color: c.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(label, style: AppFonts.label(fontSize: 14, color: selected ? c.onPrimary : c.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.site, required this.distance, required this.selected, required this.onTap, required this.onMenu});

  final RestaurantSite site;
  final double? distance;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: selected ? BorderSide(color: c.primaryInk, width: 2) : BorderSide(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SiteImage(url: site.imageUrl, size: 96, radius: 16),
              const SizedBox(width: 16),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              site.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.title(fontSize: 16, color: c.heading),
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(999)),
                              child: Text(_formatDistance(distance!), style: AppFonts.label(fontSize: 12, color: c.onPrimaryFixed)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        site.cuisine.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.label(fontSize: 12, color: c.tertiary, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(site.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text(site.categoryLabel, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
                          Material(
                            color: c.primary,
                            shape: const StadiumBorder(),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: onMenu,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text('Ver carta', style: AppFonts.label(fontSize: 14, color: c.onPrimary)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
