import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/base/base_button.dart';
import '../checkout_ui.dart';

/// Pago con tarjeta: solo visual, ningún dato sale del teléfono.
class CardPayment extends StatefulWidget {
  const CardPayment({super.key, required this.amountLabel, required this.processing, required this.onPay});

  final String amountLabel;
  final bool processing;
  final ValueChanged<String> onPay;

  @override
  State<CardPayment> createState() => _CardPaymentState();
}

/// Algoritmo de Luhn: detecta errores de tipeo en el número.
bool _passesLuhn(String value) {
  var sum = 0;

  for (var index = 0; index < value.length; index++) {
    var digit = int.parse(value[value.length - 1 - index]);

    if (index.isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }

    sum += digit;
  }

  return value.isNotEmpty && sum % 10 == 0;
}

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _groupBy4(String value) => value.replaceAllMapped(RegExp(r'(.{4})'), (match) => '${match[1]} ').trim();

TextEditingValue _collapsed(String text) => TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));

class _CardPaymentState extends State<CardPayment> {
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [_number, _holder, _expiry, _cvv]) {
      controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  String get _digits => _onlyDigits(_number.text);

  String? get _brand {
    final digits = _digits;
    if (RegExp(r'^4').hasMatch(digits)) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(digits)) return 'American Express';
    return null;
  }

  int get _cvvLength => _brand == 'American Express' ? 4 : 3;

  ({String? number, String? holder, String? expiry, String? cvv}) get _errors {
    final parts = _expiry.text.split('/');
    final month = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final year = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final now = DateTime.now();
    final expired = month == 0 ||
        year == 0 ||
        month < 1 ||
        month > 12 ||
        2000 + year < now.year ||
        (2000 + year == now.year && month < now.month);

    return (
      number: _digits.length < 13 || !_passesLuhn(_digits) ? 'Revisa el número de la tarjeta.' : null,
      holder: _holder.text.trim().length < 3 ? 'Escribe el nombre como aparece en la tarjeta.' : null,
      expiry: expired ? 'Fecha de vencimiento no válida.' : null,
      cvv: _cvv.text.length != _cvvLength ? 'El código tiene $_cvvLength dígitos.' : null,
    );
  }

  bool get _isValid {
    final errors = _errors;
    return errors.number == null && errors.holder == null && errors.expiry == null && errors.cvv == null;
  }

  String get _previewNumber => _groupBy4(_digits.padRight(16, '•'));

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _touched = true);

    if (_isValid) {
      final digits = _digits;
      widget.onPay('${_brand ?? 'Tarjeta'} •••• ${digits.substring(digits.length - 4)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final errors = _errors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _preview(),
        const SizedBox(height: 20),
        CheckoutSection(
          children: [
            CheckoutField(
              label: 'Número de tarjeta',
              error: _touched ? errors.number : null,
              child: TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.creditCardNumber],
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  // Agrupa de 4 en 4 mientras se escribe.
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final digits = _onlyDigits(newValue.text);
                    return _collapsed(_groupBy4(digits.length > 19 ? digits.substring(0, 19) : digits));
                  }),
                ],
                decoration: checkoutInputDecoration(context, hint: '0000 0000 0000 0000'),
              ),
            ),
            CheckoutField(
              label: 'Nombre en la tarjeta',
              error: _touched ? errors.holder : null,
              child: TextField(
                controller: _holder,
                autofillHints: const [AutofillHints.creditCardName],
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: checkoutInputDecoration(context, hint: 'Como aparece impreso'),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CheckoutField(
                    label: 'Vencimiento',
                    error: _touched ? errors.expiry : null,
                    child: TextField(
                      controller: _expiry,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.creditCardExpirationDate],
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          var digits = _onlyDigits(newValue.text);
                          if (digits.length > 4) digits = digits.substring(0, 4);
                          return _collapsed(digits.length > 2 ? '${digits.substring(0, 2)}/${digits.substring(2)}' : digits);
                        }),
                      ],
                      decoration: checkoutInputDecoration(context, hint: 'MM/AA'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CheckoutField(
                    label: 'CVV',
                    error: _touched ? errors.cvv : null,
                    child: TextField(
                      controller: _cvv,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.creditCardSecurityCode],
                      obscureText: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final digits = _onlyDigits(newValue.text);
                          return _collapsed(digits.length > _cvvLength ? digits.substring(0, _cvvLength) : digits);
                        }),
                      ],
                      decoration: checkoutInputDecoration(context, hint: _cvvLength == 4 ? '0000' : '000'),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: c.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vista de demostración: usa 4242 4242 4242 4242. No se guarda ni se envía ningún dato.',
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        BaseButton(
          label: widget.processing ? 'Procesando pago…' : 'Pagar ${widget.amountLabel}',
          variant: 'primary',
          size: 'lg',
          block: true,
          loading: widget.processing,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _preview() {
    final holder = _holder.text;

    return ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: AspectRatio(
            aspectRatio: 1.586,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF0F172A)],
                  ),
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 8))],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(width: 160, height: 160, decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle)),
                    ),
                    Positioned(
                      bottom: -64,
                      left: -40,
                      child: Container(width: 192, height: 192, decoration: const BoxDecoration(color: Color(0x0DFFFFFF), shape: BoxShape.circle)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFFBBF24)]),
                                ),
                              ),
                              const Spacer(),
                              Text(_brand ?? 'Tarjeta', style: AppFonts.label(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _previewNumber,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 20, letterSpacing: 2.4, color: Colors.white),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TITULAR', style: TextStyle(fontSize: 12, color: Color(0x99FFFFFF))),
                                    Text(
                                      (holder.isEmpty ? 'Nombre apellido' : holder).toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('VENCE', style: TextStyle(fontSize: 12, color: Color(0x99FFFFFF))),
                                  Text(
                                    _expiry.text.isEmpty ? 'MM/AA' : _expiry.text,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }
}
