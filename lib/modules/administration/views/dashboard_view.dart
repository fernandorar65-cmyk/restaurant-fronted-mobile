import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/landing.dart';
import '../../../router/routes.dart';
import '../../../router/site_directory.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/empty_state.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../auth/api.dart';
import '../../auth/permissions.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../../restaurants/widgets/restaurant_edit_dialog.dart';
import '../widgets/admin_form.dart';

/// Directorio de sedes operativas: el usuario elige desde qué sede opera (equivale a DashboardView.vue).
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final TextEditingController _search = TextEditingController();

  List<RestaurantSite> _restaurants = [];
  Organization? _organization;
  String? _loadError;
  bool _isLoading = true;

  /// 'all' | RestaurantCategory
  String _activeCategory = 'all';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadDirectory();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _countOf(String category) => _restaurants.where((site) => site.category == category).length;

  List<({String id, String label})> get _categoryFilters => [
        (id: 'all', label: 'Todas las sedes (${_restaurants.length})'),
        (id: 'fine-dining', label: 'Alta cocina (${_countOf('fine-dining')})'),
        (id: 'bistro', label: 'Cava y bistró (${_countOf('bistro')})'),
        (id: 'lab', label: 'I+D y laboratorio (${_countOf('lab')})'),
      ];

  List<RestaurantSite> get _filteredRestaurants {
    final query = _search.text.trim().toLowerCase();

    return _restaurants.where((site) {
      final matchesCategory = _activeCategory == 'all' || site.category == _activeCategory;

      if (!matchesCategory) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return site.name.toLowerCase().contains(query) ||
          site.city.toLowerCase().contains(query) ||
          site.code.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadDirectory() async {
    final session = context.read<SessionStore>();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<Object>([fetchRestaurants(), fetchOrganizations()]);
      // Cada usuario ve solo las sedes a las que tiene acceso.
      _restaurants = (results[0] as List<RestaurantSite>).where((site) => session.canAccessRestaurant(site.id)).toList();
      _organization = (results[1] as List<Organization>).firstOrNull;
    } catch (error) {
      _loadError = errorText(error, 'No se pudo cargar el directorio de sedes.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Alta de una sede nueva con su cantidad de pisos.
  Future<String?> _createSite(NewRestaurantDraft draft) async {
    final session = context.read<SessionStore>();
    final toast = context.read<ToastStore>();

    try {
      final site = await createRestaurant(draft);
      final user = session.user;

      // Quien la creó con acceso restringido a algunas sedes, pasa a tener acceso a esta.
      if (user != null) {
        await grantRestaurantAccess(user.id, site.id);
        await session.refreshUser();
      }

      await SiteDirectory.ensure(force: true);
      await _loadDirectory();
      final floors = draft.floorsCount ?? 1;
      toast.show(
        'Sede "${site.name}" creada',
        message: 'Con $floors ${floors == 1 ? 'piso' : 'pisos'}. Ya puedes agregar sus mesas desde Gestión de mesas.',
        tone: 'success',
      );
      return null;
    } catch (_) {
      return 'No se pudo crear la sede. Inténtalo de nuevo.';
    }
  }

  void _enterSite(RestaurantSite site) {
    final session = context.read<SessionStore>();
    session.setRestaurant(site.id);
    context.go(siteLandingRoute(session.user, site.id) ?? Routes.noAccess);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionStore>();
    final filtered = _filteredRestaurants;

    return RefreshIndicator(
      onRefresh: _loadDirectory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('PANEL DE SELECCIÓN', style: AppFonts.eyebrow(color: c.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Directorio de sedes operativas', style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Elige la sede desde la que vas a operar. Los indicadores son de demostración hasta conectar el API.',
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (session.can(Permissions.orgManage) || _organization != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (session.can(Permissions.orgManage))
                  BaseButton(
                    label: 'Nueva sede',
                    icon: Icons.add_rounded,
                    variant: 'primary',
                    onPressed: () => RestaurantEditDialog.show(context, onSave: _createSite),
                  ),
                if (_organization != null) _OrganizationChip(name: _organization!.name),
              ],
            ),
          const SizedBox(height: 16),
          TwoColumnGrid(
            children: [
              StatTile(label: 'Sedes', value: '${_restaurants.length}', hint: 'Locales en el directorio'),
              StatTile(label: 'Alta cocina', value: '${_countOf('fine-dining')}', hint: 'Sedes de esta categoría'),
              StatTile(label: 'Cava y bistró', value: '${_countOf('bistro')}', hint: 'Sedes de esta categoría'),
              StatTile(label: 'Laboratorio', value: '${_countOf('lab')}', hint: 'Sedes de I+D'),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _categoryFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: _activeCategory == filter.id,
                      onSelected: (_) => setState(() => _activeCategory = filter.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Filtrar por nombre, ciudad o código...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(tooltip: 'Limpiar', icon: const Icon(Icons.close_rounded), onPressed: _search.clear),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const SkeletonBlock(rows: 2)
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else if (filtered.isEmpty)
            const EmptyState(title: 'No hay sedes que coincidan con el filtro.', icon: 'search')
          else
            for (final site in filtered) ...[
              _RestaurantSiteCard(
                restaurant: site,
                isSelected: session.restaurantId == site.id,
                onEnter: () => _enterSite(site),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _OrganizationChip extends StatelessWidget {
  const _OrganizationChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_rounded, size: 20, color: c.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ORGANIZACIÓN', style: AppFonts.eyebrow(color: c.outline, fontSize: 10)),
              Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una sede del directorio (equivale a RestaurantSiteCard.vue).
class _RestaurantSiteCard extends StatelessWidget {
  const _RestaurantSiteCard({required this.restaurant, required this.isSelected, required this.onEnter});

  final RestaurantSite restaurant;
  final bool isSelected;
  final VoidCallback onEnter;

  // Sobre la foto se usan colores fijos (como en el front web): el fondo es siempre oscuro.
  static const Map<RestaurantBadgeTone, (Color, Color)> _badgeColors = {
    'amber': (Color(0xFFF59E0B), Color(0xFF020617)),
    'wine': (Color(0xFFB45309), Colors.white),
    'blue': (Color(0xFF2563EB), Colors.white),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kpis = restaurant.kpis;
    final (badgeBackground, badgeForeground) =
        restaurant.badgeTone == 'emerald' ? (c.success, c.onSuccess) : (_badgeColors[restaurant.badgeTone] ?? _badgeColors['blue']!);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFF0F172A),
                  child: restaurant.imageUrl.isEmpty
                      ? null
                      : Image.network(
                          restaurant.imageUrl,
                          fit: BoxFit.cover,
                          semanticLabel: restaurant.name,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xB3000000), Color(0x33000000), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 90,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _OverlayPill(
                        background: badgeBackground,
                        child: Text(
                          restaurant.badgeLabel.toUpperCase(),
                          style: AppFonts.label(fontSize: 11, fontWeight: FontWeight.w700, color: badgeForeground),
                        ),
                      ),
                      _OverlayPill(
                        background: const Color(0xCC022C22),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(restaurant.statusLabel, style: AppFonts.label(fontSize: 11, color: const Color(0xFF6EE7B7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _OverlayPill(
                    background: const Color(0x99000000),
                    child: Text(
                      restaurant.code,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.cuisine.toUpperCase(), style: AppFonts.eyebrow(color: const Color(0xFFFCD34D))),
                      Text(
                        restaurant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.headline(fontSize: 22, color: Colors.white, height: 1.15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: c.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(restaurant.capacityLabel, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: c.outline)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.6)),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _KpiBox(
                          label: 'Facturación hoy',
                          value: kpis.revenueLabel,
                          middle: Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(color: c.successContainer, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              kpis.revenueHint,
                              maxLines: 2,
                              style: AppFonts.label(fontSize: 10, fontWeight: FontWeight.w700, color: c.onSuccessContainer),
                            ),
                          ),
                          footer: Text(kpis.marginLabel, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KpiBox(
                          label: 'Estado de stock',
                          value: kpis.stockLabel,
                          middle: Text(kpis.stockHint, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
                          footer: Text(kpis.stockNote, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.success)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KpiBox(
                          label: 'Aforo',
                          value: kpis.occupancyLabel,
                          middle: Text(kpis.occupancyHint, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
                          footer: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: (kpis.occupancyPercent / 100).clamp(0, 1).toDouble(),
                              minHeight: 6,
                              color: c.primary,
                              backgroundColor: c.surfaceContainerHigh,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.6)),
                ),
                Text.rich(
                  TextSpan(
                    text: 'Rol: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                    children: [TextSpan(text: restaurant.roleLabel, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface))],
                  ),
                ),
                const SizedBox(height: 10),
                isSelected
                    ? OutlinedButton(
                        onPressed: onEnter,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: c.primary,
                          backgroundColor: c.primary.withValues(alpha: 0.1),
                          side: BorderSide(color: c.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Sede activa', style: AppFonts.label(fontSize: 14, color: c.primary)),
                      )
                    : BaseButton(label: 'Entrar a sala de mando', variant: 'primary', block: true, onPressed: onEnter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
        child: child,
      );
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({required this.label, required this.value, required this.middle, required this.footer});

  final String label;
  final String value;
  final Widget middle;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppFonts.label(fontSize: 9.5, fontWeight: FontWeight.w700, color: c.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppFonts.headline(fontSize: 15, fontWeight: FontWeight.w700, color: c.onSurface)),
          ),
          middle,
          const Spacer(),
          const SizedBox(height: 4),
          footer,
        ],
      ),
    );
  }
}
