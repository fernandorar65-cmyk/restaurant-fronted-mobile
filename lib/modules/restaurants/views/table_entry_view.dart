import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/feedback/diner_notice.dart';
import '../../orders/api.dart';
import '../../orders/types.dart';
import '../api.dart';
import '../types.dart';

enum _Step { checking, error, confirm, wrongTable }

/// Entrada por QR (/table/:tableId?restaurant=…&token=…): valida la mesa y pide confirmarla.
class TableEntryView extends StatefulWidget {
  const TableEntryView({super.key, required this.tableId});

  final String tableId;

  @override
  State<TableEntryView> createState() => _TableEntryViewState();
}

class _TableEntryViewState extends State<TableEntryView> {
  _Step _step = _Step.checking;
  DinerNoticeKind _errorKind = 'invalid-qr';
  RestaurantSite? _restaurant;
  Attention? _openAttention;
  String? _restaurantId;
  String? _token;
  String? _validatedKey;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = GoRouterState.of(context).uri.queryParameters;
    _restaurantId = query['restaurant'];
    _token = query['token'];
    _scheduleValidation();
  }

  @override
  void didUpdateWidget(covariant TableEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleValidation();
  }

  /// Revalida cuando cambia la mesa, la sede o el token de la ruta.
  void _scheduleValidation() {
    final key = '${widget.tableId}|$_restaurantId|$_token';
    if (key == _validatedKey) return;
    _validatedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _validate();
    });
  }

  void _fail(DinerNoticeKind kind) {
    setState(() {
      _errorKind = kind;
      _step = _Step.error;
    });
  }

  /// Valida el QR (sede activa, mesa existente y habilitada, token vigente) y fija el
  /// contexto del comensal. Si ya confirmó esta misma mesa, va directo a la carta.
  Future<void> _validate() async {
    final seq = ++_seq;
    final table = widget.tableId.isEmpty ? null : widget.tableId;
    final restaurantId = _restaurantId;
    final token = _token;
    final diner = context.read<DinerStore>();
    setState(() => _step = _Step.checking);

    if (table == null || restaurantId == null || token == null) {
      _fail('invalid-qr');
      return;
    }

    try {
      final results = await Future.wait([fetchRestaurantById(restaurantId), fetchSiteOperation(restaurantId)]);
      if (!mounted || seq != _seq) return;
      final site = results[0] as RestaurantSite?;
      final operation = results[1] as SiteOperation?;
      LiveTable? liveTable;
      for (final item in operation?.tables ?? const <LiveTable>[]) {
        if (item.number == table) {
          liveTable = item;
          break;
        }
      }

      if (site == null || liveTable == null || liveTable.qrToken != token || !liveTable.qrActive) {
        _fail('invalid-qr');
        return;
      }

      if (!isRestaurantOpen(site)) {
        _fail('restaurant-closed');
        return;
      }

      if (liveTable.status == 'maintenance') {
        _fail('table-maintenance');
        return;
      }

      if (liveTable.status == 'inactive') {
        _fail('table-inactive');
        return;
      }

      _restaurant = site;
      final alreadyConfirmed = diner.confirmed && diner.restaurantId == site.id && diner.tableNumber == table;

      diner.setTable(
        restaurantId: site.id,
        restaurantSlug: site.slug,
        restaurantName: site.name,
        currency: site.currency,
        tableNumber: table,
        entry: 'qr',
      );

      final open = await fetchOpenAttentionForTable(site.id, table);
      if (!mounted || seq != _seq) return;
      _openAttention = open;

      if (alreadyConfirmed) {
        diner.setAttention(open?.id ?? diner.attentionId);
        context.go(diner.menuRoute);
        return;
      }

      setState(() => _step = _Step.confirm);
    } catch (_) {
      if (mounted && seq == _seq) _fail('connection');
    }
  }

  void _continueAs(String mode) {
    final diner = context.read<DinerStore>();
    diner.setAttention(_openAttention?.id);

    if (mode == 'account' && diner.customer == null) {
      context.push(Uri(path: Routes.dinerAuth, queryParameters: {'redirect': diner.menuRoute}).toString());
      return;
    }

    diner.confirmTable();
    context.go(diner.menuRoute);
  }

  void _rejectTable() {
    context.read<DinerStore>().leaveTable();
    setState(() => _step = _Step.wrongTable);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();

    switch (_step) {
      case _Step.checking:
        return Center(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 4, color: c.primaryInk, backgroundColor: c.primaryFixed),
                ),
                const SizedBox(height: 12),
                Text('Buscando tu mesa…', style: TextStyle(fontSize: 16, color: c.onSurfaceVariant)),
              ],
            ),
          ),
        );
      case _Step.error:
        return SingleChildScrollView(child: DinerNotice(kind: _errorKind, onRetry: _validate));
      case _Step.wrongTable:
        return const SingleChildScrollView(
          child: DinerNotice(
            kind: 'no-table',
            title: 'Escanea el QR de tu mesa',
            message: 'Cada mesa tiene su propio código. Escanea el que está en tu mesa o pide ayuda a un mozo.',
          ),
        );
      case _Step.confirm:
        break;
    }

    final restaurant = _restaurant;
    if (restaurant == null) return const SizedBox.shrink();
    final customer = diner.customer;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HeadingText('¿Estás en esta ', accent: 'mesa?', fontSize: 30, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
                      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                    child: Column(
                      children: [
                        Image.network(
                          restaurant.imageUrl,
                          height: 144,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          semanticLabel: restaurant.name,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 144,
                            color: c.surfaceContainer,
                            alignment: Alignment.center,
                            child: Icon(Icons.storefront_outlined, size: 40, color: c.outline),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                restaurant.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text('Mesa ${widget.tableId}', textAlign: TextAlign.center, style: AppFonts.title(fontSize: 48, color: c.heading)),
                              const SizedBox(height: 4),
                              Text(restaurant.address, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_openAttention != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.groups_outlined, size: 20, color: c.onPrimaryFixed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tu mesa ya tiene un pedido en curso: lo que pidas se suma a la misma cuenta.',
                              style: TextStyle(fontSize: 14, color: c.onPrimaryFixed),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  BaseButton(
                    label: customer != null ? 'Sí, es mi mesa · pedir como ${customer.name}' : 'Sí, es mi mesa · ver la carta',
                    variant: 'primary',
                    size: 'lg',
                    block: true,
                    onPressed: () => _continueAs(customer != null ? 'account' : 'guest'),
                  ),
                  const SizedBox(height: 12),
                  BaseButton(label: 'No es mi mesa', size: 'lg', block: true, onPressed: _rejectTable),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        customer != null ? '¿No eres ${customer.name}?' : 'No necesitas cuenta para pedir.',
                        style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.primaryInk),
                        onPressed: customer != null ? () => diner.setCustomer(null) : () => _continueAs('account'),
                        child: Text(
                          customer != null ? 'Pedir como invitado' : 'Iniciar sesión (opcional)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
