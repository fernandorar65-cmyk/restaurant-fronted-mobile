import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../widgets/navigation/theme_menu.dart';
import '../brand.dart';
import '../../../widgets/base/app_logo.dart';

/// Pantalla de acceso común a clientes y restaurantes: misma estructura y estilo,
/// con pestañas Ingresar / Crear cuenta y un enlace para cambiar de tipo de cuenta.
/// En móvil lleva una imagen compacta de cabecera (la vitrina de la web).
///
/// audience: 'customer' | 'restaurant'; mode: 'login' | 'register'.
class AuthMinimalLayout extends StatelessWidget {
  const AuthMinimalLayout({
    super.key,
    required this.audience,
    required this.mode,
    required this.title,
    this.subtitle,
    this.hideSwitches = false,
    required this.child,
    this.footer,
  });

  final String audience;
  final String mode;
  final String title;
  final String? subtitle;

  /// Oculta pestañas y cambio de tipo (por ejemplo, con la sesión ya iniciada).
  final bool hideSwitches;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCustomer = audience == 'customer';
    // Se conserva ?redirect al cambiar de pestaña.
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
    String withQuery(String path) => redirect == null ? path : Uri(path: path, queryParameters: {'redirect': redirect}).toString();

    final routes = isCustomer
        ? (login: Routes.dinerAuth, register: Routes.dinerRegister)
        : (login: Routes.login, register: Routes.register);
    final other = isCustomer
        ? (label: '¿Tienes un restaurante?', action: 'Entra como dueño', to: mode == 'login' ? Routes.login : Routes.register)
        : (label: '¿Eres cliente?', action: 'Entra como cliente', to: mode == 'login' ? Routes.dinerAuth : Routes.dinerRegister);

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _Hero(onHome: () => context.go(Routes.home))),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCustomer ? c.primaryFixed : c.tertiaryFixed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isCustomer ? 'Cliente' : 'Restaurante',
                              style: AppFonts.label(fontSize: 12, color: isCustomer ? c.onPrimaryFixed : c.onTertiaryContainer),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(title, textAlign: TextAlign.center, style: AppFonts.title(fontSize: 30, color: c.heading, height: 1.2)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 24),
                        if (!hideSwitches) ...[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                for (final tab in [
                                  (key: 'login', label: 'Ingresar', to: routes.login),
                                  (key: 'register', label: 'Crear cuenta', to: routes.register),
                                ])
                                  Expanded(
                                    child: _Tab(
                                      label: tab.label,
                                      active: mode == tab.key,
                                      onTap: mode == tab.key ? null : () => context.replace(withQuery(tab.to)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        child,
                        if (!hideSwitches) ...[
                          const SizedBox(height: 24),
                          Divider(color: c.outlineVariant.withValues(alpha: 0.5), height: 1),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('${other.label} ', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                              TextButton(
                                style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4)),
                                onPressed: () => context.go(other.to),
                                child: Text(other.action, style: AppFonts.label(fontSize: 14, color: c.primaryInk)),
                              ),
                            ],
                          ),
                        ],
                        if (footer != null) ...[const SizedBox(height: 24), footer!],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: active ? c.surfaceContainerLowest : Colors.transparent,
      elevation: active ? 1 : 0,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(label, style: AppFonts.label(fontSize: 14, color: active ? c.onSurface : c.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }
}

/// Cabecera compacta: foto del restaurante con la marca y el selector de tema encima.
class _Hero extends StatelessWidget {
  const _Hero({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 168 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            authShowcaseImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => ColoredBox(color: c.primaryContainer),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x33000000), Color(0xB3000000)],
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 4,
            child: Row(
              children: [
                Semantics(
                  label: 'RentaSol, ir al inicio',
                  button: true,
                  child: InkWell(
                    onTap: onHome,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          const AppLogo(size: 36),
                          const SizedBox(width: 10),
                          Text('RentaSol', style: AppFonts.headline(fontSize: 18, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(color: c.surfaceContainerLowest.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const ThemeMenu(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
