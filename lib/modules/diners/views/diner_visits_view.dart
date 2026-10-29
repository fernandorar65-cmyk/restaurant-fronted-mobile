import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/base/status_badge.dart';
import '../../orders/api.dart';
import '../../orders/order_status_labels.dart';
import '../../orders/types.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';

typedef _Visit = ({Attention attention, RestaurantSite? restaurant, double total});

/// Historial de visitas del comensal con cuenta (/mis-visitas).
class DinerVisitsView extends StatefulWidget {
  const DinerVisitsView({super.key});

  @override
  State<DinerVisitsView> createState() => _DinerVisitsViewState();
}

class _DinerVisitsViewState extends State<DinerVisitsView> {
  List<_Visit> _visits = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    final customer = context.read<DinerStore>().customer;

    if (customer == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _loadError = null);

    try {
      final results = await Future.wait<Object>([
        fetchAttentionsByCustomer(customer.id),
        fetchAllOrderedProducts(),
        fetchRestaurants(),
      ]);
      final attentions = results[0] as List<Attention>;
      final products = results[1] as List<OrderedProduct>;
      final restaurants = results[2] as List<RestaurantSite>;

      final visits = attentions.map((attention) {
        RestaurantSite? restaurant;
        for (final site in restaurants) {
          if (site.id == attention.restaurantId) {
            restaurant = site;
            break;
          }
        }
        final total = products
            .where((product) => product.attentionId == attention.id && isBillableProduct(product.status))
            .fold<double>(0, (sum, product) => sum + product.subtotal);
        return (attention: attention, restaurant: restaurant, total: total);
      }).toList();

      if (mounted) setState(() => _visits = visits);
    } catch (error) {
      if (mounted) setState(() => _loadError = errorMessage(error, 'No se pudo cargar tu historial.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customer = context.watch<DinerStore>().customer;

    final emptyBox = BoxDecoration(
      color: c.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
    );

    return RefreshIndicator(
      onRefresh: _loadVisits,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Mis visitas', style: AppFonts.title(fontSize: 30, color: c.heading)),
          if (customer != null) Text('Historial de ${customer.name}', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (customer == null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: emptyBox,
              child: Column(
                children: [
                  Text(
                    'Ingresa con tu cuenta para ver el historial de tus visitas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  BaseButton(
                    label: 'Ingresar',
                    variant: 'primary',
                    onPressed: () => context.push(Uri(path: Routes.dinerAuth, queryParameters: {'redirect': Routes.dinerVisits}).toString()),
                  ),
                ],
              ),
            )
          else if (_isLoading)
            const SkeletonBlock(variant: 'list', rows: 3)
          else if (_loadError != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(8)),
              child: Text(_loadError!, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
            )
          else if (_visits.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: emptyBox,
              child: Text(
                'Todavía no tienes visitas registradas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
            )
          else
            for (final visit in _visits)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: c.surfaceContainerLowest,
                  elevation: 1,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(Routes.orderStatus(visit.attention.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${visit.restaurant?.name ?? 'Restaurante'} · Mesa ${visit.attention.tableNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.headline(fontSize: 14, color: c.onSurface),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDateTime(visit.attention.openedAt, visit.restaurant?.timezone),
                                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(visit.total, visit.restaurant?.currency ?? 'EUR'),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(
                                tone: attentionStatusTone[visit.attention.status] ?? 'neutral',
                                label: attentionStatusLabel[visit.attention.status] ?? visit.attention.status,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
