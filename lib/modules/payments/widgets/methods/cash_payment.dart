import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../widgets/base/base_button.dart';
import '../../checkout.dart';
import '../checkout_ui.dart';

const Map<FulfillmentMode, String> _where = {
  'dine-in': 'Pagas al personal en tu mesa.',
  'pickup': 'Pagas en caja cuando llegues al local.',
  'delivery': 'Pagas al repartidor cuando recibas tu pedido.',
};

/// Pago en efectivo al recibir: indica con cuánto paga para llevar el vuelto preparado.
class CashPayment extends StatefulWidget {
  const CashPayment({
    super.key,
    required this.amount,
    required this.currency,
    required this.mode,
    required this.processing,
    required this.onPay,
  });

  final double amount;
  final String currency;
  final FulfillmentMode? mode;
  final bool processing;
  final ValueChanged<String> onPay;

  @override
  State<CashPayment> createState() => _CashPaymentState();
}

class _CashPaymentState extends State<CashPayment> {
  final _custom = TextEditingController();
  double? _payWith;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _custom.addListener(_rebuild);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// Montos habituales: exacto y los siguientes billetes redondos.
  List<double> get _quickAmounts {
    final options = <double>{widget.amount};

    for (final step in const [10, 20, 50, 100]) {
      options.add(((widget.amount / step).ceil() * step).toDouble());
    }

    return (options.toList()..sort()).take(4).toList();
  }

  bool get _hasCustom => _custom.text.isNotEmpty;

  /// null = no indicó monto; NaN = escribió algo que no es un número.
  double? get _selected => _hasCustom ? (double.tryParse(_custom.text.replaceAll(',', '.')) ?? double.nan) : _payWith;

  double? get _change {
    final selected = _selected;
    return selected != null ? selected - widget.amount : null;
  }

  String? get _error {
    final selected = _selected;

    if (selected == null || selected.isNaN) {
      return 'Indica con cuánto vas a pagar.';
    }

    return selected < widget.amount ? 'El monto no cubre el total.' : null;
  }

  void _choose(double value) {
    _custom.clear();
    setState(() => _payWith = value);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _touched = true);
    final selected = _selected;

    if (_error == null && selected != null) {
      final change = _change;
      final detail = change != null && change > 0
          ? 'Efectivo · paga con ${formatMoney(selected, widget.currency)}, vuelto ${formatMoney(change, widget.currency)}'
          : 'Efectivo · monto exacto';
      widget.onPay(detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quick = _quickAmounts;
    final change = _change;
    final mode = widget.mode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckoutSection(
          spacing: 16,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text('A pagar', style: AppFonts.headline(fontSize: 18, color: c.onSurface))),
                Text(formatMoney(widget.amount, widget.currency), style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
              ],
            ),
            if (mode != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: c.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_where[mode] ?? '', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))),
                  ],
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('¿Con cuánto pagarás?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: quick.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 48,
                  ),
                  itemBuilder: (context, index) {
                    final value = quick[index];
                    final selected = !_hasCustom && _payWith == value;

                    return Material(
                      color: selected ? c.primary : c.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _choose(value),
                        child: Center(
                          child: Text(
                            index == 0 ? 'Exacto' : formatMoney(value, widget.currency),
                            style: AppFonts.label(fontSize: 14, color: selected ? c.onPrimary : c.onSurface),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            CheckoutField(
              label: 'Otro monto',
              child: TextField(
                controller: _custom,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: checkoutInputDecoration(context, hint: '0,00'),
              ),
            ),
            if (change != null && !change.isNaN && change > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.successContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: Text('Tu vuelto', style: TextStyle(fontSize: 14, color: c.onSuccessContainer))),
                    Text(
                      formatMoney(change, widget.currency),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.onSuccessContainer),
                    ),
                  ],
                ),
              ),
            if (_touched && _error != null) Text(_error!, style: TextStyle(fontSize: 12, color: c.error)),
          ],
        ),
        const SizedBox(height: 20),
        BaseButton(
          label: widget.processing ? 'Confirmando…' : 'Confirmar pedido',
          variant: 'primary',
          size: 'lg',
          block: true,
          loading: widget.processing,
          onPressed: _submit,
        ),
      ],
    );
  }
}
