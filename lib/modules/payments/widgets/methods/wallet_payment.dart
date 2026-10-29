import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/base/base_button.dart';
import '../checkout_ui.dart';

/// Datos de ejemplo hasta tener la cuenta real del restaurante.
const String _payeePhone = '987 654 321';

const Map<String, ({String name, Color accent, String app})> _wallets = {
  'yape': (name: 'Yape', accent: Color(0xFF742284), app: 'tu app Yape'),
  'plin': (name: 'Plin', accent: Color(0xFF00A19B), app: 'la app de tu banco con Plin'),
};

/// Pago con billetera móvil (Yape o Plin): QR, número de destino y código de operación. Solo visual.
class WalletPayment extends StatefulWidget {
  const WalletPayment({
    super.key,
    required this.wallet,
    required this.amount,
    required this.amountLabel,
    required this.payeeName,
    required this.processing,
    required this.onPay,
  });

  /// 'yape' | 'plin'
  final String wallet;
  final double amount;
  final String amountLabel;
  final String payeeName;
  final bool processing;
  final ValueChanged<String> onPay;

  @override
  State<WalletPayment> createState() => _WalletPaymentState();
}

class _WalletPaymentState extends State<WalletPayment> {
  final _operationCode = TextEditingController();
  bool _touched = false;
  bool _copied = false;
  Timer? _copiedTimer;

  ({String name, Color accent, String app}) get _info => _wallets[widget.wallet] ?? _wallets['yape']!;

  String? get _error =>
      RegExp(r'^\d{6,10}$').hasMatch(_operationCode.text) ? null : 'Ingresa el código de operación (6 a 10 dígitos).';

  /// Lo que codifica el QR (la web lo genera con api.qrserver.com; aquí se dibuja en el teléfono).
  String get _qrPayload =>
      '${widget.wallet}:${_payeePhone.replaceAll(' ', '')}?monto=${widget.amount.toStringAsFixed(2)}&nombre=${widget.payeeName}';

  @override
  void initState() {
    super.initState();
    _operationCode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _operationCode.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _copyPhone() async {
    try {
      await Clipboard.setData(ClipboardData(text: _payeePhone.replaceAll(' ', '')));
      _copiedTimer?.cancel();
      if (!mounted) return;
      setState(() => _copied = true);
      _copiedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      // Portapapeles no disponible: el número sigue visible.
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _touched = true);

    if (_error == null) {
      widget.onPay('${_info.name} · operación ${_operationCode.text}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = _info;

    Widget step(int number, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primaryFixed, shape: BoxShape.circle),
                child: Text('$number', style: AppFonts.label(fontSize: 12, fontWeight: FontWeight.w700, color: c.onPrimaryFixed)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Container(
                color: info.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(info.name, style: AppFonts.headline(fontSize: 18, color: Colors.white))),
                    Text(widget.amountLabel, style: AppFonts.headline(fontSize: 20, color: Colors.white)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Código QR para pagar con ${info.name}',
                      image: true,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: QrImageView(data: _qrPayload, size: 192, backgroundColor: Colors.white, padding: EdgeInsets.zero),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Escanea el código con ${info.app}\no envía el monto al número:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: c.surfaceContainer,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _copyPhone,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _payeePhone,
                                  style: AppFonts.label(fontSize: 16, fontWeight: FontWeight.w700, color: c.onSurface, letterSpacing: 0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(_copied ? 'Copiado' : 'Copiar', style: AppFonts.label(fontSize: 12, color: c.primaryInk)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text: 'A nombre de ',
                        children: [
                          TextSpan(text: widget.payeeName, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        step(1, 'Abre ${info.app} y escanea el QR o usa el número.'),
        step(2, 'Paga exactamente ${widget.amountLabel}.'),
        step(3, 'Escribe aquí el código de operación que te muestra la app.'),
        const SizedBox(height: 20),
        CheckoutSection(
          spacing: 4,
          children: [
            CheckoutField(
              label: 'Código de operación',
              error: _touched ? _error : null,
              child: TextField(
                controller: _operationCode,
                keyboardType: TextInputType.number,
                maxLength: 10,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 16, letterSpacing: 2.4, color: c.onSurface),
                decoration: checkoutInputDecoration(context, hint: 'Ej: 12345678').copyWith(
                  counterText: '',
                  hintStyle: TextStyle(letterSpacing: 0, color: c.outline),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Vista de demostración: el número y el QR son de ejemplo.',
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        BaseButton(
          label: widget.processing ? 'Verificando pago…' : 'Ya pagué',
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
