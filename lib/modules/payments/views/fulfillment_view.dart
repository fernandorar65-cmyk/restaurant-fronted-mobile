import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../router/routes.dart';
import '../../../stores/cart_store.dart';
import '../../../stores/checkout_store.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/diner_notice.dart';
import '../checkout.dart';
import '../checkout_controller.dart';
import '../../restaurants/types.dart';
import '../widgets/checkout_ui.dart';

const List<({FulfillmentMode mode, String description, IconData icon})> _modes = [
  (mode: 'dine-in', description: 'Ya estás en el restaurante', icon: Icons.room_service_outlined),
  (mode: 'pickup', description: 'Lo dejamos listo para cuando llegues', icon: Icons.schedule_rounded),
  (mode: 'delivery', description: 'Te lo llevamos a tu dirección', icon: Icons.local_shipping_outlined),
];

/// Paso 1 del checkout: cómo recibe el comensal su pedido (en mesa, llego al local o delivery).
class FulfillmentView extends StatefulWidget {
  const FulfillmentView({super.key});

  @override
  State<FulfillmentView> createState() => _FulfillmentViewState();
}

class _FulfillmentViewState extends State<FulfillmentView> {
  late final CheckoutController _checkout;
  late final DinerStore _diner;
  late final CheckoutStore _store;
  late final TextEditingController _tableCode;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _reference = TextEditingController();

  bool _showErrors = false;
  bool _locating = false;
  String? _locationError;
  bool _wasLoading = true;
  String? _modesKey;

  @override
  void initState() {
    super.initState();
    _diner = context.read<DinerStore>();
    _store = context.read<CheckoutStore>();
    _checkout = CheckoutController(diner: _diner, cart: context.read<CartStore>(), checkout: _store);
    _tableCode = TextEditingController(text: _diner.tableCode ?? '');
    _checkout.addListener(_onChanged);
    // Equivale al `watch(availableModes, …, { immediate: true })` de la web (fuera del build).
    scheduleMicrotask(_watchModes);
  }

  @override
  void dispose() {
    _checkout.removeListener(_onChanged);
    _checkout.dispose();
    _tableCode.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    _watchModes();

    // Al terminar de cargar, los campos toman el borrador guardado (y el nombre de la cuenta).
    if (_wasLoading && !_checkout.isLoading) {
      _name.text = _store.contact.name;
      _phone.text = _store.contact.phone;
      _address.text = _store.delivery.address;
      _reference.text = _store.delivery.reference;
    }

    _wasLoading = _checkout.isLoading;
    setState(() {});
  }

  /// Preselección: con código de mesa guardado, "En mesa"; si la sede ofrece una sola modalidad, esa.
  void _watchModes() {
    if (!mounted) return;
    final modes = _checkout.availableModes;
    final key = modes.join(',');

    if (key == _modesKey) {
      return;
    }

    _modesKey = key;
    final current = _store.mode;

    if (current != null && modes.contains(current)) {
      return;
    }

    if (_diner.tableCode != null && modes.contains('dine-in')) {
      _store.setMode('dine-in');
    } else {
      _store.setMode(modes.length == 1 ? modes.first : null);
    }
  }

  /// El código de mesa se guarda mientras se escribe.
  void _onTableCodeChanged(String value) {
    final restaurantId = _diner.restaurantId;

    if (restaurantId == null) {
      return;
    }

    if (value.trim().isNotEmpty) {
      _diner.setTableCode(restaurantId, value);
    } else {
      _diner.clearTableCode();
    }
  }

  Future<void> _shareLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('denied');
      }

      // Como `maximumAge: 300000` en la web: sirve una posición de hace menos de 5 minutos.
      Position? position;

      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && DateTime.now().difference(last.timestamp) < const Duration(minutes: 5)) {
          position = last;
        }
      } catch (_) {
        position = null;
      }

      position ??= await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)));
      _store.delivery.lat = position.latitude;
      _store.delivery.lng = position.longitude;
      _store.save();
    } catch (_) {
      if (mounted) setState(() => _locationError = 'No pudimos obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _continueToPayment() {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);

    if (_checkout.fulfillmentError == null) {
      context.push(Routes.checkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    final diner = context.watch<DinerStore>();
    final options = _checkout.site?.fulfillment;

    final List<Widget> content;
    var ready = false;

    if (cart.items.isEmpty) {
      content = [
        DinerNotice(
          kind: 'info',
          title: 'Tu orden está vacía',
          message: 'Agrega platos desde la carta para continuar.',
          actions: [BaseButton(label: 'Ver la carta', variant: 'primary', onPressed: () => context.go(diner.menuRoute))],
        ),
      ];
    } else if (_checkout.isLoading) {
      content = const [SkeletonBlock(rows: 3)];
    } else if (_checkout.loadError || options == null) {
      content = [DinerNotice(kind: 'connection', onRetry: _checkout.reload)];
    } else {
      ready = true;
      content = _form(options);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckoutTitle(title: '¿Cómo quieres recibir tu pedido?', subtitle: diner.restaurantName),
                const SizedBox(height: 24),
                for (var index = 0; index < content.length; index++) ...[
                  if (index > 0) const SizedBox(height: 16),
                  content[index],
                ],
              ],
            ),
          ),
        ),
        if (ready) _summaryBar(context),
      ],
    );
  }

  List<Widget> _form(SiteFulfillment options) {
    final mode = _store.mode;

    return [
      _modeSelector(),
      if (mode == 'dine-in') _dineInSection(),
      if (mode == 'pickup' || mode == 'delivery') _contactSection(),
      if (mode == 'pickup') _pickupSection(),
      if (mode == 'delivery') _deliverySection(options),
    ];
  }

  Widget _modeSelector() {
    final c = context.colors;
    final available = _checkout.availableModes;

    return Semantics(
      label: 'Modalidad de entrega',
      container: true,
      child: Column(
        children: [
          for (final option in _modes) ...[
            if (option != _modes.first) const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final enabled = available.contains(option.mode);
                final selected = _store.mode == option.mode;

                return Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: selected,
                    enabled: enabled,
                    child: Material(
                      color: c.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selected ? c.primary : c.outlineVariant.withValues(alpha: 0.4),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: enabled ? () => _store.setMode(option.mode) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selected ? c.primary : c.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(option.icon, color: selected ? c.onPrimary : c.onSurfaceVariant),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fulfillmentLabel[option.mode]!,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                                    ),
                                    Text(
                                      enabled ? option.description : 'No disponible en esta sede',
                                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _dineInSection() {
    final c = context.colors;

    return CheckoutSection(
      children: [
        CheckoutField(
          label: 'Código de mesa',
          child: TextField(
            controller: _tableCode,
            maxLength: 30,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: _onTableCodeChanged,
            decoration: checkoutInputDecoration(context, hint: 'Ej: 12 o T-04').copyWith(counterText: ''),
          ),
        ),
        Text('Lo encuentras en la placa o tarjeta de tu mesa.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
      ],
    );
  }

  Widget _contactSection() {
    return CheckoutSection(
      children: [
        const CheckoutSectionTitle('Tus datos'),
        CheckoutField(
          label: 'Nombre',
          child: TextField(
            controller: _name,
            autofillHints: const [AutofillHints.name],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: checkoutInputDecoration(context),
            onChanged: (value) {
              _store.contact.name = value;
              _store.save();
            },
          ),
        ),
        CheckoutField(
          label: 'Teléfono',
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            decoration: checkoutInputDecoration(context, hint: '+51 999 999 999'),
            onChanged: (value) {
              _store.contact.phone = value;
              _store.save();
            },
          ),
        ),
      ],
    );
  }

  Widget _pickupSection() {
    final c = context.colors;
    final slots = _checkout.arrivalSlots;
    final pickup = _store.pickup;

    return CheckoutSection(
      spacing: 16,
      children: [
        CheckoutSectionTitle('¿A qué hora llegas?', subtitle: 'Tu pedido tarda unos ${_checkout.prepMinutes} min en estar listo.'),
        Semantics(
          label: 'Dónde comerás',
          container: true,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                for (final choice in const [(value: true, label: 'Como en el local'), (value: false, label: 'Para llevar')])
                  Expanded(
                    child: Semantics(
                      inMutuallyExclusiveGroup: true,
                      checked: pickup.eatIn == choice.value,
                      child: Material(
                        color: pickup.eatIn == choice.value ? c.surfaceContainerLowest : Colors.transparent,
                        elevation: pickup.eatIn == choice.value ? 1 : 0,
                        shadowColor: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            pickup.eatIn = choice.value;
                            _store.save();
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Center(
                              child: Text(
                                choice.label,
                                style: AppFonts.label(
                                  fontSize: 14,
                                  color: pickup.eatIn == choice.value ? c.onSurface : c.onSurfaceVariant,
                                ),
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
        ),
        if (slots.isEmpty)
          Text('Ya no quedan horarios disponibles para hoy.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))
        else
          Semantics(
            label: 'Hora de llegada',
            container: true,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 44,
              ),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final selected = pickup.arrivalTime == slot;

                return Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: selected,
                  child: Material(
                    color: selected ? c.primary : c.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        pickup.arrivalTime = slot;
                        _store.save();
                      },
                      child: Center(
                        child: Text(
                          slot,
                          style: AppFonts.label(fontSize: 14, color: selected ? c.onPrimary : c.onSurface)
                              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (pickup.eatIn)
          Text(
            'Al llegar, escanea el QR de tu mesa o dale tu nombre al personal y te sirven.',
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _deliverySection(SiteFulfillment options) {
    final c = context.colors;
    final currency = _diner.currency;
    final distance = _checkout.deliveryDistanceKm;
    final radius = options.deliveryRadiusKm;

    return CheckoutSection(
      children: [
        const CheckoutSectionTitle('¿Dónde lo entregamos?'),
        CheckoutField(
          label: 'Dirección',
          child: TextField(
            controller: _address,
            keyboardType: TextInputType.streetAddress,
            autofillHints: const [AutofillHints.fullStreetAddress],
            textInputAction: TextInputAction.next,
            decoration: checkoutInputDecoration(context, hint: 'Calle, número, piso'),
            onChanged: (value) {
              _store.delivery.address = value;
              _store.save();
            },
          ),
        ),
        CheckoutField(
          label: 'Referencia (opcional)',
          child: TextField(
            controller: _reference,
            textInputAction: TextInputAction.done,
            decoration: checkoutInputDecoration(context, hint: 'Ej: portón negro, timbre 3B'),
            onChanged: (value) {
              _store.delivery.reference = value;
              _store.save();
            },
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BaseButton(
              label: 'Comprobar con mi ubicación',
              icon: Icons.location_on_outlined,
              loading: _locating,
              onPressed: _shareLocation,
            ),
            if (distance != null)
              Text(
                'A ${distance.toStringAsFixed(1)} km · '
                '${distance <= radius ? 'dentro de la zona de entrega' : 'fuera de la zona de entrega'}',
                style: TextStyle(fontSize: 14, color: distance <= radius ? c.success : c.error),
              )
            else if (_locationError != null)
              Text(_locationError!, style: TextStyle(fontSize: 14, color: c.error)),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text('Entregamos hasta ${formatPlainNumber(radius)} km de la sede.'),
                Text('Envío: ${formatMoney(options.deliveryFee, currency)}'),
                if (options.minOrder > 0) Text('Pedido mínimo: ${formatMoney(options.minOrder, currency)}'),
                Text('Llega en unos ${_checkout.prepMinutes + 20} min.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryBar(BuildContext context) {
    final cart = context.watch<CartStore>();
    final currency = _diner.currency;
    final error = _checkout.fulfillmentError;

    return CheckoutActionBar(
      children: [
        Column(
          children: [
            CheckoutAmountRow(label: 'Productos (${cart.itemCount})', value: formatMoney(_checkout.subtotal, currency)),
            if (_store.mode == 'delivery') CheckoutAmountRow(label: 'Envío', value: formatMoney(_checkout.deliveryFee, currency)),
            CheckoutAmountRow(label: 'Total', value: formatMoney(_checkout.total, currency), total: true),
          ],
        ),
        if (_showErrors && error != null) CheckoutAlert(error),
        BaseButton(label: 'Continuar al pago', variant: 'primary', size: 'lg', block: true, onPressed: _continueToPayment),
      ],
    );
  }
}
