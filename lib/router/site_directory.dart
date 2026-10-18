import '../modules/restaurants/api.dart';
import '../modules/restaurants/types.dart';

/// Directorio de sedes en memoria para traducir entre el slug de la URL
/// (/owner/sede/bodega-san-telmo-grand-cru) y el id que usan la API y los permisos.
class SiteDirectory {
  SiteDirectory._();

  static List<RestaurantSite>? _sites;
  static Future<void>? _pending;

  static Future<void> ensure({bool force = false}) async {
    if (_sites != null && !force) {
      return;
    }

    _pending ??= fetchRestaurants().then((list) {
      _sites = list;
    }).whenComplete(() {
      _pending = null;
    });

    await _pending;
  }

  /// Sede por slug (o por id). Si no la encuentra, recarga una vez por si es una sede recién creada.
  static Future<({String id, String slug})?> find(String slugOrId) async {
    await ensure();
    var match = lookup(slugOrId);

    if (match == null) {
      await ensure(force: true);
      match = lookup(slugOrId);
    }

    return match == null ? null : (id: match.id, slug: match.slug);
  }

  /// Búsqueda síncrona en lo ya cargado.
  static RestaurantSite? lookup(String slugOrId) {
    final sites = _sites ?? const <RestaurantSite>[];

    for (final site in sites) {
      if (site.slug == slugOrId) return site;
    }

    for (final site in sites) {
      if (site.id == slugOrId) return site;
    }

    return null;
  }

  /// Slug de una sede ya cargada. Si el directorio aún no cargó, usa el id como respaldo.
  static String slugFor(String id) => lookup(id)?.slug ?? id;

  /// Id de la sede para un slug ya cargado (null si no está).
  static String? idFor(String slug) => lookup(slug)?.id;
}
