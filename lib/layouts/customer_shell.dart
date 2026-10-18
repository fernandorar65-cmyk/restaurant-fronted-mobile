import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../router/routes.dart';
import '../stores/cart_store.dart';
import '../stores/diner_store.dart';
import '../widgets/navigation/profile_menu.dart';
import '../widgets/navigation/theme_menu.dart';

/// Layout del comensal: barra superior con la sede y la mesa, contenido y navegación inferior.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final diner = context.watch<DinerStore>();
    final cart = context.watch<CartStore>();
    final c = context.colors;
    final path = state.uri.path;
    // En el inicio el comensal todavía está eligiendo sede: se muestra la marca, no la última sede.
    final isHome = path == Routes.home;
    // El acceso rápido al carrito solo tiene sentido mientras se mira la carta de una sede.
    final isMenu = RegExp(r'^/[^/]+/menu$').hasMatch(path);
    final title = (isHome ? null : diner.restaurantName) ?? 'RentaSol';
    final items = _navItems(diner, cart);
    final selected = items.indexWhere((item) => item.matches(path));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          onTap: () => context.go(Routes.home),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.menu_book_outlined, size: 18, color: c.onPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, overflow: TextOverflow.ellipsis, style: AppFonts.headline(fontSize: 16, color: c.onSurface)),
                    if (isHome || diner.restaurantId == null)
                      Text('Pide desde tu mesa', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (diner.tableNumber != null && !isHome)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(999)),
              child: Text('Mesa ${diner.tableNumber}', style: AppFonts.label(fontSize: 12, color: c.onPrimaryFixed)),
            ),
          const ThemeMenu(),
          const ProfileMenu(),
          if (isMenu)
            IconButton(
              tooltip: 'Ver carrito',
              onPressed: () => context.push(Routes.cart),
              icon: Badge(
                isLabelVisible: cart.itemCount > 0,
                label: Text(cart.itemCount > 99 ? '99+' : '${cart.itemCount}'),
                backgroundColor: c.primary,
                textColor: c.onPrimary,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: selected < 0 ? 0 : selected,
        indicatorColor: selected < 0 ? Colors.transparent : c.primaryFixed,
        onDestinationSelected: (index) => context.go(items[index].to),
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: (item.badge ?? 0) > 0,
                label: Text('${item.badge ?? 0}'),
                child: Icon(item.icon),
              ),
              selectedIcon: Badge(
                isLabelVisible: (item.badge ?? 0) > 0,
                label: Text('${item.badge ?? 0}'),
                child: Icon(item.selectedIcon),
              ),
              label: item.label,
            ),
        ],
      ),
    );
  }

  List<_NavItem> _navItems(DinerStore diner, CartStore cart) {
    return [
      _NavItem(
        label: 'Carta',
        to: diner.menuRoute,
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        matches: (path) => path == Routes.home || RegExp(r'^/[^/]+/menu$').hasMatch(path),
      ),
      if (diner.isReadyToOrder || cart.itemCount > 0)
        _NavItem(
          label: 'Carrito',
          to: Routes.cart,
          icon: Icons.shopping_bag_outlined,
          selectedIcon: Icons.shopping_bag_rounded,
          badge: cart.itemCount,
          matches: (path) => path == Routes.cart,
        ),
      if (diner.attentionId != null) ...[
        _NavItem(
          label: 'Mi pedido',
          to: Routes.orderStatus(diner.attentionId!),
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule_rounded,
          matches: (path) => RegExp(r'^/orders/[^/]+$').hasMatch(path),
        ),
        _NavItem(
          label: 'Cuenta',
          to: Routes.orderAccount(diner.attentionId!),
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          matches: (path) => RegExp(r'^/orders/[^/]+/cuenta$').hasMatch(path),
        ),
      ],
      _NavItem(
        label: diner.customer != null ? 'Perfil' : 'Ingresar',
        to: diner.customer != null ? Routes.dinerProfile : Routes.access,
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        matches: (path) => [Routes.access, Routes.dinerProfile, Routes.dinerVisits].contains(path),
      ),
    ];
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.to, required this.icon, required this.selectedIcon, required this.matches, this.badge});

  final String label;
  final String to;
  final IconData icon;
  final IconData selectedIcon;
  final int? badge;
  final bool Function(String path) matches;
}
