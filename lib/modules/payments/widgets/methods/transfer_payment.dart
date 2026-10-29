import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/base/base_button.dart';
import '../checkout_ui.dart';

/// Datos de ejemplo hasta tener la cuenta real de cada sede.
const _account = [
  (label: 'Banco', value: 'Banco Demo'),
  (label: 'Cuenta corriente', value: '191-0000000-0-00'),
  (label: 'CCI', value: '002-191-000000000000-00'),
];

/// Transferencia bancaria: datos de la cuenta y comprobante. Solo visual; el archivo no se sube.
///
/// La app aún no incluye un selector de archivos: tocar la zona del comprobante adjunta
/// uno simulado (solo su nombre), igual que la web, que tampoco lo sube.
class TransferPayment extends StatefulWidget {
  const TransferPayment({
    super.key,
    required this.amountLabel,
    required this.payeeName,
    required this.processing,
    required this.onPay,
  });

  final String amountLabel;
  final String payeeName;
  final bool processing;
  final ValueChanged<String> onPay;

  @override
  State<TransferPayment> createState() => _TransferPaymentState();
}

class _TransferPaymentState extends State<TransferPayment> {
  String? _copiedLabel;
  Timer? _copiedTimer;

  /// Nombre del comprobante adjunto.
  String? _voucher;
  bool _touched = false;

  String? get _error => _voucher != null ? null : 'Adjunta el comprobante de la transferencia.';

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String label, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value.replaceAll('-', '')));
      _copiedTimer?.cancel();
      if (!mounted) return;
      setState(() => _copiedLabel = label);
      _copiedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copiedLabel = null);
      });
    } catch (_) {
      // Portapapeles no disponible: el dato sigue visible.
    }
  }

  void _pickVoucher() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    setState(() => _voucher = 'comprobante-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg');
  }

  void _submit() {
    setState(() => _touched = true);
    final voucher = _voucher;

    if (_error == null && voucher != null) {
      widget.onPay('Transferencia · comprobante $voucher');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final divider = Divider(height: 1, thickness: 1, color: c.outlineVariant.withValues(alpha: 0.5));

    Widget row({required String label, required String value, bool mono = false, Widget? trailing}) => Padding(
          padding: EdgeInsets.fromLTRB(12, 10, trailing == null ? 12 : 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface,
                        fontFamily: mono ? 'monospace' : null,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        );

    final hasVoucher = _voucher != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckoutSection(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text('Transfiere a esta cuenta', style: AppFonts.headline(fontSize: 18, color: c.onSurface))),
                const SizedBox(width: 12),
                Text(widget.amountLabel, style: AppFonts.headline(fontSize: 20, color: c.onSurface)),
              ],
            ),
            Container(
              decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  row(label: 'Titular', value: widget.payeeName),
                  for (final item in _account) ...[
                    divider,
                    row(
                      label: item.label,
                      value: item.value,
                      mono: true,
                      trailing: item.label == 'Banco'
                          ? null
                          : TextButton(
                              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                              onPressed: () => _copy(item.label, item.value),
                              child: Text(
                                _copiedLabel == item.label ? 'Copiado' : 'Copiar',
                                style: AppFonts.label(fontSize: 12, color: c.primaryInk),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            Text('Vista de demostración: los datos bancarios son de ejemplo.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 20),
        CheckoutSection(
          children: [
            const CheckoutSectionTitle('Comprobante'),
            Material(
              color: hasVoucher ? c.primaryFixed.withValues(alpha: 0.3) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: hasVoucher ? c.primaryInk : c.outlineVariant, width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickVoucher,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 112),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hasVoucher ? Icons.description_outlined : Icons.upload_rounded, size: 32, color: hasVoucher ? c.primaryInk : c.outline),
                        const SizedBox(height: 8),
                        Text(
                          _voucher ?? 'Sube la captura o el PDF',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                        ),
                        Text(
                          hasVoucher ? 'Toca para cambiarlo' : 'JPG, PNG o PDF',
                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_touched && _error != null) Text(_error!, style: TextStyle(fontSize: 12, color: c.error)),
          ],
        ),
        const SizedBox(height: 20),
        BaseButton(
          label: widget.processing ? 'Enviando comprobante…' : 'Enviar comprobante',
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
