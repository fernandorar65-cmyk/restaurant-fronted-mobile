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
import '../../orders/api.dart' show errorMessage;
import '../../orders/order_status_labels.dart';

import '../api.dart';
import '../types.dart';

/// Historial de visitas del comensal con cuenta (/mis-visitas).
class DinerVisitsView extends StatefulWidget {
  const DinerVisitsView({super.key});

  @override
  State<DinerVisitsView> createState() => _DinerVisitsViewState();
}

class _DinerVisitsViewState extends State<DinerVisitsView> {
  List<CustomerVisit> _visits = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    final diner = context.read<DinerStore>();

    if (diner.customer == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _loadError = null);

    try {
      final visits = await fetchCustomerVisits(diner);
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${visit.restaurantName} · ${visit.number}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.headline(fontSize: 14, color: c.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDateTime(visit.openedAt, visit.timezone),
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
                              formatMoney(visit.total, visit.currency),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                            ),
                            const SizedBox(height: 4),
                            StatusBadge(
                              tone: attentionStatusTone[visit.status] ?? 'neutral',
                              label: attentionStatusLabel[visit.status] ?? visit.status,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
