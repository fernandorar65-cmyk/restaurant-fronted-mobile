import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../../restaurants/widgets/restaurant_edit_dialog.dart';
import '../widgets/admin_form.dart';

const Map<RestaurantOperationalStatus, String> _statusLabels = {
  'active': 'Activo',
  'inactive': 'Inactivo',
  'suspended': 'Suspendido',
};

const Map<RestaurantOperationalStatus, StatusTone> _statusTone = {
  'active': 'success',
  'inactive': 'muted',
  'suspended': 'danger',
};

/// Sedes de la organización (equivale a RestaurantsAdminView.vue).
class RestaurantsAdminView extends StatefulWidget {
  const RestaurantsAdminView({super.key});

  @override
  State<RestaurantsAdminView> createState() => _RestaurantsAdminViewState();
}

class _RestaurantsAdminViewState extends State<RestaurantsAdminView> {
  List<RestaurantSite> _restaurants = [];
  String? _loadError;
  String? _actionError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      _restaurants = await fetchRestaurants();
    } catch (error) {
      _loadError = errorText(error, 'No se pudieron cargar las sedes.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _saveRestaurant(RestaurantSite? original, NewRestaurantDraft draft) async {
    setState(() => _actionError = null);

    try {
      if (original != null) {
        // El código de la sede no se edita una vez creada.
        final updated = await updateRestaurant(
          original.id,
          RestaurantDraft(
            name: draft.name,
            city: draft.city,
            address: draft.address,
            cuisine: draft.cuisine,
            status: draft.status,
            statusLabel: draft.statusLabel,
            category: draft.category,
            categoryLabel: draft.categoryLabel,
            currency: draft.currency,
            timezone: draft.timezone,
          ),
          imageUrl: draft.imageUrl,
        );
        if (mounted) setState(() => _restaurants = _restaurants.map((item) => item.id == updated.id ? updated : item).toList());
      } else {
        final created = await createRestaurant(draft);
        if (mounted) setState(() => _restaurants = [..._restaurants, created]);
      }

      return null;
    } catch (_) {
      return 'No se pudo guardar la sede.';
    }
  }

  void _openDialog(RestaurantSite? restaurant) {
    RestaurantEditDialog.show(context, restaurant: restaurant, onSave: (draft) => _saveRestaurant(restaurant, draft));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminPageHeader(
            section: 'Restaurantes',
            title: 'Restaurantes',
            description: 'Sedes de la organización: datos generales, moneda, zona horaria y estado operativo.',
            actions: [
              BaseButton(label: 'Sede', icon: Icons.add_rounded, variant: 'primary', onPressed: () => _openDialog(null)),
            ],
          ),
          const SizedBox(height: 20),
          if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
          if (_isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_loadError != null)
            InlineAlert(_loadError!)
          else
            for (final restaurant in _restaurants) ...[
              _RestaurantCard(restaurant: restaurant, onEdit: () => _openDialog(restaurant)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.onEdit});

  final RestaurantSite restaurant;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.code.toUpperCase(), style: AppFonts.eyebrow(color: c.tertiary)),
                    Text(restaurant.name, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                    Text('${restaurant.city} · ${restaurant.categoryLabel}', style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BaseButton(label: 'Editar', size: 'sm', onPressed: onEdit),
            ],
          ),
          const SizedBox(height: 10),
          if (restaurant.address.isNotEmpty) Text(restaurant.address, style: muted),
          if (restaurant.cuisine.isNotEmpty) Text(restaurant.cuisine, style: muted),
          Text('Moneda ${restaurant.currency} · ${restaurant.timezone}', style: muted),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                tone: _statusTone[restaurant.status] ?? 'neutral',
                label: (_statusLabels[restaurant.status] ?? restaurant.status).toUpperCase(),
              ),
              if (restaurant.statusLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                  child: Text(restaurant.statusLabel, style: AppFonts.label(fontSize: 12, color: c.primary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
