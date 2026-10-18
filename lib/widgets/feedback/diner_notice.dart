import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../base/base_button.dart';

/// 'invalid-qr' | 'table-maintenance' | 'table-inactive' | 'restaurant-not-found' | 'restaurant-closed'
/// | 'empty-menu' | 'attention-closed' | 'connection' | 'no-table' | 'info'
typedef DinerNoticeKind = String;

const Map<DinerNoticeKind, ({String title, String message, String tone})> _defaults = {
  'invalid-qr': (
    title: 'Código QR no válido',
    message: 'Este código QR no es válido o fue desactivado. Pide ayuda a un mozo.',
    tone: 'error',
  ),
  'table-maintenance': (
    title: 'Mesa en mantenimiento',
    message: 'Esta mesa no está disponible por ahora. Un mozo te ayudará a ubicarte en otra.',
    tone: 'error',
  ),
  'table-inactive': (
    title: 'Mesa no habilitada',
    message: 'Esta mesa no está habilitada para pedir. Pide ayuda a un mozo.',
    tone: 'error',
  ),
  'restaurant-not-found': (
    title: 'No encontramos esta sede',
    message: 'La dirección no corresponde a ninguna sede. Revisa el enlace o elige una sede desde el inicio.',
    tone: 'neutral',
  ),
  'restaurant-closed': (
    title: 'Sede no disponible',
    message: 'Esta sede no está recibiendo pedidos en este momento.',
    tone: 'error',
  ),
  'empty-menu': (
    title: 'Carta no disponible',
    message: 'Esta sede todavía no publicó su carta. Pide ayuda a un mozo.',
    tone: 'neutral',
  ),
  'attention-closed': (
    title: 'Esta cuenta ya se cerró',
    message: 'La atención de esta mesa ya terminó. Si quieres pedir de nuevo, vuelve a escanear el QR de tu mesa.',
    tone: 'neutral',
  ),
  'connection': (
    title: 'Sin conexión',
    message: 'No pudimos conectarnos con el restaurante. Revisa tu conexión e inténtalo de nuevo.',
    tone: 'error',
  ),
  'no-table': (
    title: 'Escanea el QR de tu mesa',
    message: 'Para hacer un pedido necesitamos saber en qué mesa estás. Escanea el código QR que está en tu mesa.',
    tone: 'primary',
  ),
  'info': (title: '', message: '', tone: 'neutral'),
};

/// Aviso a pantalla completa para el comensal (QR inválido, sin conexión, etc.).
class DinerNotice extends StatelessWidget {
  const DinerNotice({super.key, required this.kind, this.title, this.message, this.onRetry, this.actions = const []});

  final DinerNoticeKind kind;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final config = _defaults[kind] ?? _defaults['info']!;
    final (Color background, Color foreground) = switch (config.tone) {
      'error' => (c.errorContainer, c.onErrorContainer),
      'primary' => (c.primary, c.onPrimary),
      _ => (c.surfaceContainer, c.onSurfaceVariant),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minHeight: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
                child: Icon(
                  config.tone == 'error' ? Icons.warning_amber_rounded : (kind == 'no-table' ? Icons.qr_code_scanner_rounded : Icons.info_outline_rounded),
                  color: foreground,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(title ?? config.title, textAlign: TextAlign.center, style: AppFonts.headline(fontSize: 20, color: c.onSurface)),
              const SizedBox(height: 8),
              Text(message ?? config.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (kind == 'connection' && onRetry != null)
                    BaseButton(label: 'Reintentar', variant: 'primary', size: 'lg', onPressed: onRetry),
                  ...actions,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
