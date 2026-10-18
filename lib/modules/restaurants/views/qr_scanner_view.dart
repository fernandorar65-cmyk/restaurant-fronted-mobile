import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../widgets/base/base_button.dart';

/// Ruta de mesa (con su query) a partir del texto de un QR. Acepta una URL o ruta que
/// contenga `/table/<id>` (se conservan `?restaurant=…&token=…`) o un id de mesa suelto.
String? tableRouteFromScan(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  final match = RegExp(r'/table/([^/?#]+)').firstMatch(uri?.path ?? text);

  if (match != null) {
    final id = Uri.decodeComponent(match.group(1)!);
    final query = uri?.queryParameters ?? const <String, String>{};
    final path = Routes.tableEntry(Uri.encodeComponent(id));
    return query.isEmpty ? path : Uri(path: path, queryParameters: query).toString();
  }

  // Id de mesa suelto (sin espacios ni barras).
  if (RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(text)) {
    return Routes.tableEntry(text);
  }

  return null;
}

/// Escáner de QR a pantalla completa. Se abre con `Navigator.push` desde el inicio.
class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  String? _invalid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final route = tableRouteFromScan(raw);

      if (route != null) {
        _handled = true;
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.go(route);
        return;
      }

      setState(() => _invalid = 'Este código no corresponde a una mesa. Escanea el QR que está en tu mesa.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          // Marco guía del QR.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Cerrar',
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
                          final on = state.torchState == TorchState.on;
                          return IconButton(
                            tooltip: on ? 'Apagar linterna' : 'Encender linterna',
                            color: Colors.white,
                            iconSize: 28,
                            onPressed: _controller.toggleTorch,
                            icon: Icon(on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        'Escanea el QR de tu mesa',
                        textAlign: TextAlign.center,
                        style: AppFonts.headline(fontSize: 20, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Apunta la cámara al código que está en tu mesa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      if (_invalid != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                          child: Text(_invalid!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onErrorContainer)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 48, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                denied ? 'No diste permiso para usar la cámara' : 'No pudimos abrir la cámara',
                textAlign: TextAlign.center,
                style: AppFonts.headline(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Activa el permiso de cámara en los ajustes del teléfono, o pide ayuda a un mozo.'
                    : 'Inténtalo de nuevo o pide ayuda a un mozo.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              BaseButton(label: 'Volver', variant: 'primary', onPressed: () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      ),
    );
  }
}
