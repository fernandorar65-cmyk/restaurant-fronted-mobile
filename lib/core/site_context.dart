import 'package:flutter/foundation.dart';

import '../modules/restaurants/api.dart';
import '../modules/restaurants/types.dart';
import '../router/site_directory.dart';
import '../stores/session_store.dart';
import 'http/http_client.dart';

/// Sede de la ruta actual (`/owner/sede/:siteSlug`) para las vistas del portal
/// (equivale a `useSiteContext`). Traduce el slug al id, fija la sede activa en la
/// sesión y llama a [onReady] cada vez que carga.
///
/// ```dart
/// late final site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadData)..load();
/// ```
class SiteContext extends ChangeNotifier {
  SiteContext(this.siteSlug, {required this.session, required this.onReady});

  String siteSlug;
  final SessionStore session;
  final Future<void> Function(RestaurantSite site) onReady;

  RestaurantSite? restaurant;
  String? restaurantId;
  bool isLoading = true;
  String? loadError;

  String get currency => restaurant?.currency ?? 'EUR';

  /// Cambia de sede (si la ruta cambió) y recarga.
  Future<void> setSlug(String next) async {
    if (next == siteSlug) return;
    siteSlug = next;
    await load();
  }

  Future<void> load() async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final match = await SiteDirectory.find(siteSlug);
      restaurantId = match?.id;

      if (restaurantId == null) {
        loadError = 'No se indicó una sede.';
        return;
      }

      session.setRestaurant(restaurantId!);
      final site = await fetchRestaurantById(restaurantId!);
      restaurant = site;

      if (site == null) {
        loadError = 'La sede no existe.';
        return;
      }

      await onReady(site);
    } on HttpError catch (error) {
      loadError = error.message;
    } catch (_) {
      loadError = 'No se pudieron cargar los datos de la sede.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Equivale a `reload` del composable.
  Future<void> reload() => load();
}
