import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/time.dart';
import '../../../router/routes.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../administration/widgets/admin_form.dart';
import '../../finance/period.dart' show parseDateKey, toDateKey;
import '../../orders/api.dart';
import '../../orders/types.dart';
import '../../payments/api.dart';
import '../../payments/types.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../metrics.dart';
import '../widgets/ranked_bars.dart';

/// Resumen de caja de un día de la sede y registro del cierre (equivale a DailyClosingView.vue).
class DailyClosingView extends StatefulWidget {
  const DailyClosingView({super.key, required this.siteSlug});

  final String siteSlug;

  @override
  State<DailyClosingView> createState() => _DailyClosingViewState();
}

class _DailyClosingViewState extends State<DailyClosingView> {
  late final SiteContext _site;
  List<Attention> _attentions = [];
  List<Payment> _payments = [];
  List<DailyClosingRecord> _closings = [];
  String _dateKey = '';
  bool _isSaving = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadData)..addListener(_onSiteChanged);
    _site.load();
  }

  @override
  void didUpdateWidget(covariant DailyClosingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteSlug != widget.siteSlug) _site.setSlug(widget.siteSlug);
  }

  @override
  void dispose() {
    _site.removeListener(_onSiteChanged);
    _site.dispose();
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData(RestaurantSite site) async {
    final results = await Future.wait<Object>([
      fetchAttentionsBySite(site.id),
      fetchAllPayments(),
      fetchDailyClosings(site.id),
    ]);
    _attentions = results[0] as List<Attention>;
    _payments = results[1] as List<Payment>;
    _closings = results[2] as List<DailyClosingRecord>;

    if (_dateKey.isEmpty) {
      _dateKey = localDateKey(nowIso(), site.timezone);
    }
  }

  DailyClosingSummary _summary(RestaurantSite restaurant) => computeDailyClosing(
        attentions: _attentions,
        payments: _payments,
        dateKey: _dateKey,
        timeZone: restaurant.timezone,
      );

  String _money(num value) => formatMoney(value, _site.currency);

  Future<void> _pickDate() async {
    final current = _dateKey.isEmpty ? DateTime.now() : parseDateKey(_dateKey);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Fecha',
    );
    if (picked != null) setState(() => _dateKey = toDateKey(picked));
  }

  Future<void> _registerClosing() async {
    final restaurant = _site.restaurant;

    if (restaurant == null) {
      return;
    }

    final summary = _summary(restaurant);
    final session = context.read<SessionStore>();
    final toast = context.read<ToastStore>();

    if (summary.open > 0 &&
        !(await confirmAction(
          context,
          title: 'Quedan ${summary.open} mesas con la cuenta abierta',
          message: 'Lo ideal es cobrarlas antes de cerrar el día. ¿Quieres registrar el cierre igualmente?',
          confirmLabel: 'Registrar igualmente',
        ))) {
      return;
    }

    setState(() {
      _isSaving = true;
      _actionError = null;
    });

    try {
      final saved = await saveDailyClosing(restaurant.id, summary, session.user?.name);
      _closings = [saved, ..._closings.where((closing) => closing.id != saved.id)];
      toast.show('Cierre registrado', message: '${saved.dateKey} · ${_money(saved.totalPaid)}', tone: 'success');
    } catch (_) {
      _actionError = 'No se pudo registrar el cierre.';
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = _site.restaurant;

    return RefreshIndicator(
      onRefresh: _site.reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_site.isLoading)
            const SkeletonBlock(variant: 'page')
          else if (_site.loadError != null)
            InlineAlert(_site.loadError!)
          else if (restaurant != null)
            ..._content(context.colors, restaurant),
        ],
      ),
    );
  }

  List<Widget> _content(AppColors c, RestaurantSite restaurant) {
    final summary = _summary(restaurant);
    final existingClosing = _closings.where((closing) => closing.dateKey == _dateKey).firstOrNull;
    final paymentLabel = paymentMethodLabel;

    Widget card(String title, Widget child) => AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        );

    return [
      SitePageHeader(
        restaurant: restaurant,
        section: 'Cierre del día',
        title: 'Cierre del día',
        description: 'Resumen de caja por fecha (zona horaria ${restaurant.timezone}).',
        actions: [
          BaseButton(label: _dateKey, icon: Icons.calendar_today_outlined, onPressed: _pickDate),
          BaseButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: _site.reload),
          BaseButton(
            label: existingClosing != null ? 'Actualizar cierre' : 'Registrar cierre',
            variant: 'primary',
            loading: _isSaving,
            onPressed: _registerClosing,
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_actionError != null) ...[InlineAlert(_actionError!), const SizedBox(height: 12)],
      if (summary.open > 0) ...[
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.tertiaryFixed.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.tertiaryContainer),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: c.onSurface),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Quedan ${summary.open} atenciones abiertas de este día:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final attention in summary.openAttentions)
                      BaseButton(
                        label: 'Mesa ${attention.tableNumber} · ${formatTime(attention.openedAt, restaurant.timezone)}',
                        size: 'sm',
                        onPressed: () => context.go(Routes.siteAccountDetail(restaurant.slug, attention.id)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      TwoColumnGrid(
        children: [
          StatTile(label: 'Cobrado', value: _money(summary.totalPaid)),
          StatTile(label: 'Cerradas', value: '${summary.closed}'),
          StatTile(label: 'Abiertas', value: '${summary.open}', valueColor: summary.open > 0 ? c.error : null),
          StatTile(
            label: 'Canceladas',
            value: '${summary.cancelled}',
            hint: summary.pendingPayments > 0 ? '${summary.pendingPayments} pagos sin confirmar' : null,
          ),
        ],
      ),
      const SizedBox(height: 16),
      card(
        'Por método de pago',
        RankedBars(
          items: [
            for (final row in summary.byMethod) RankedItem(label: '${paymentLabel[row.method] ?? row.method} (${row.count})', value: row.amount),
          ],
          format: _money,
          emptyLabel: 'No hubo cobros este día.',
        ),
      ),
      const SizedBox(height: 16),
      card(
        'Por empleado que cobró',
        RankedBars(
          items: [for (final row in summary.byEmployee) RankedItem(label: '${row.name} (${row.count})', value: row.amount)],
          format: _money,
          emptyLabel: 'No hubo cobros este día.',
        ),
      ),
      const SizedBox(height: 24),
      Text('Cierres registrados', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
      const SizedBox(height: 10),
      if (_closings.isEmpty)
        Text('Todavía no se registró ningún cierre.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))
      else
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < _closings.length; index++) ...[
                if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4)),
                ListTile(
                  selected: _closings[index].dateKey == _dateKey,
                  onTap: () => setState(() => _dateKey = _closings[index].dateKey),
                  title: Text(_closings[index].dateKey, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${_closings[index].closedAttentions} cerradas · ${_closings[index].openAttentions} abiertas · '
                    'por ${_closings[index].closedBy ?? '—'} el ${formatDateTime(_closings[index].createdAt, restaurant.timezone)}',
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                  trailing: Text(
                    _money(_closings[index].totalPaid),
                    style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }
}
