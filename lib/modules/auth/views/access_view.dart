import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';

/// Punto de entrada único para iniciar sesión o registrarse: el usuario elige si es
/// cliente o dueño de restaurante y va al formulario que corresponde (/acceso?modo=registro).
class AccessView extends StatelessWidget {
  const AccessView({super.key, this.mode});

  final String? mode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isRegister = mode == 'registro';

    final options = [
      (
        title: 'Soy cliente',
        description: isRegister ? 'Crea tu cuenta para pedir más rápido.' : 'Entra a tu cuenta de cliente.',
        perks: const ['Guarda tus visitas y pedidos', 'Tus preferencias y alergias', 'Paga y sigue tu pedido'],
        to: isRegister ? Routes.dinerRegister : Routes.dinerAuth,
        background: c.primaryFixed,
        foreground: c.onPrimaryFixed,
        icon: Icons.person_outline_rounded,
      ),
      (
        title: 'Soy dueño de restaurante',
        description: isRegister ? 'Registra tu restaurante en RentaSol.' : 'Entra al portal de tu restaurante.',
        perks: const ['Gestiona tu carta y precios', 'Recibe pedidos y cobra', 'Administra sedes y personal'],
        to: isRegister ? Routes.register : Routes.login,
        background: c.tertiaryFixed,
        foreground: c.onTertiaryContainer,
        icon: Icons.storefront_outlined,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text(
          isRegister ? 'Crea tu cuenta' : 'Inicia sesión',
          textAlign: TextAlign.center,
          style: AppFonts.headline(fontSize: 26, color: c.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          '¿Cómo quieres ${isRegister ? 'registrarte' : 'entrar'}?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        for (final option in options) ...[
          Material(
            color: c.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(option.to),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: option.background, borderRadius: BorderRadius.circular(16)),
                          child: Icon(option.icon, color: option.foreground),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option.title, style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
                              Text(option.description, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: c.outline),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    for (final perk in option.perks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_rounded, size: 16, color: c.success),
                            const SizedBox(width: 8),
                            Expanded(child: Text(perk, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(isRegister ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.primary),
              onPressed: () => context.go(isRegister ? Routes.access : '${Routes.access}?modo=registro'),
              child: Text(isRegister ? 'Inicia sesión' : 'Regístrate', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}
