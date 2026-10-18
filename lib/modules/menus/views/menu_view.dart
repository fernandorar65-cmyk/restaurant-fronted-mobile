import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/string.dart';
import '../../../router/routes.dart';
import '../../../stores/cart_store.dart';
import '../../../stores/diner_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/diner_notice.dart';
import '../../restaurants/api.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/menu_product_card.dart';
import '../widgets/menu_product_detail_dialog.dart';
import '../widgets/menu_search.dart';

const double _tabsHeight = 60;

/// Carta del comensal (/:restaurantSlug/menu).
class MenuView extends StatefulWidget {
  const MenuView({super.key, required this.restaurantSlug});

  final String restaurantSlug;

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  final ScrollController _tabsScroll = ScrollController();

  /// Sede de la URL.
  RestaurantSite? _site;
  List<MenuCategory> _categories = [];
  List<MenuProduct> _products = [];
  DinerNoticeKind? _notice;
  bool _isLoading = true;
  String? _activeCategoryId;
  bool _isProgrammaticScroll = false;
  int _loadSeq = 0;

  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _tabKeys = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _search.addListener(_onSearchChanged);
    _loadMenu();
  }

  @override
  void didUpdateWidget(covariant MenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantSlug != widget.restaurantSlug) {
      _loadMenu();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _tabsScroll.dispose();
    super.dispose();
  }

  String get _currency => _site?.currency ?? context.read<DinerStore>().currency;

  void _onSearchChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  /// [silent]: recarga al deslizar hacia abajo, sin volver al esqueleto de carga.
  Future<void> _loadMenu({bool silent = false}) async {
    final seq = ++_loadSeq;
    final diner = context.read<DinerStore>();
    final cart = context.read<CartStore>();

    if (!silent) {
      setState(() {
        _isLoading = true;
        _notice = null;
        _site = null;
        _categories = [];
        _products = [];
      });
    }

    DinerNoticeKind? notice;
    RestaurantSite? site;
    List<MenuCategory> categories = [];
    List<MenuProduct> products = [];

    try {
      final found = await fetchRestaurantBySlug(widget.restaurantSlug);

      if (found == null) {
        notice = 'restaurant-not-found';
      } else if (!isRestaurantOpen(found)) {
        notice = 'restaurant-closed';
      } else {
        site = found;

        // Sin mesa activa, abrir la carta de una sede la convierte en la sede actual (modo consulta).
        if (!diner.isReadyToOrder && diner.restaurantId != found.id) {
          diner.browse(restaurantId: found.id, restaurantSlug: found.slug, restaurantName: found.name, currency: found.currency);
        }

        if (diner.restaurantId == found.id) {
          cart.ensureRestaurant(found.id);
        }

        final menu = await fetchCustomerMenu(found.id);

        if (menu.products.isEmpty) {
          notice = 'empty-menu';
        } else {
          categories = menu.categories.where((category) => menu.products.any((product) => product.categoryId == category.id)).toList();
          products = menu.products;
        }
      }
    } catch (_) {
      notice = 'connection';
    }

    if (!mounted || seq != _loadSeq) return;

    setState(() {
      _isLoading = false;
      _notice = notice;
      _site = site;
      _categories = categories;
      _products = products;
      if (!silent || !categories.any((category) => category.id == _activeCategoryId)) {
        _activeCategoryId = categories.isEmpty ? null : categories.first.id;
      }
      for (final category in categories) {
        _sectionKeys.putIfAbsent(category.id, GlobalKey.new);
        _tabKeys.putIfAbsent(category.id, GlobalKey.new);
      }
      _sectionKeys.removeWhere((id, _) => !categories.any((category) => category.id == id));
      _tabKeys.removeWhere((id, _) => !categories.any((category) => category.id == id));
    });
  }

  List<({MenuCategory category, List<MenuProduct> items})> get _productsByCategory {
    final query = normalizeSearch(_search.text);
    final hasQuery = _search.text.trim().isNotEmpty;

    return _categories
        .map((category) => (
              category: category,
              items: _products.where((product) {
                if (product.categoryId != category.id) return false;
                if (query.isEmpty) return true;
                return normalizeSearch('${product.name} ${product.description}').contains(query);
              }).toList(),
            ))
        .where((group) => group.items.isNotEmpty || !hasQuery)
        .toList();
  }

  /// Se puede agregar a la orden en la sede actual del comensal, tenga mesa o no.
  /// Si tiene mesa en otra sede, esta carta es solo de consulta para no mezclar carritos.
  bool _canOrder(DinerStore diner) => _site != null && diner.restaurantId == _site!.id;

  void _increase(MenuProduct product) {
    final diner = context.read<DinerStore>();
    if (_canOrder(diner) && product.isAvailable) {
      context.read<CartStore>().addItem(productId: product.id, name: product.name, price: product.price);
    }
  }

  void _decrease(MenuProduct product) {
    final cart = context.read<CartStore>();
    cart.setQuantity(product.id, cart.quantityOf(product.id) - 1);
  }

  /// Producto elegido (tarjeta o buscador): se abre su detalle con los datos ya cargados de la carta.
  void _openDetail(MenuProduct product) {
    final diner = context.read<DinerStore>();
    final resolved = _products.firstWhere((item) => item.id == product.id, orElse: () => product);

    showMenuProductDetailDialog(
      context,
      product: resolved,
      currency: _currency,
      orderable: _canOrder(diner),
      onIncrease: () => _increase(resolved),
      onDecrease: () => _decrease(resolved),
    );
  }

  /// Posición de scroll en la que la sección queda justo debajo de las pestañas fijas.
  double? _sectionOffset(String categoryId) {
    final box = _sectionKeys[categoryId]?.currentContext?.findRenderObject();
    if (box == null || !box.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    return viewport.getOffsetToReveal(box, 0).offset - _tabsHeight;
  }

  Future<void> _scrollToCategory(String categoryId) async {
    setState(() => _activeCategoryId = categoryId);
    _revealActiveTab();

    await WidgetsBinding.instance.endOfFrame;
    final target = _sectionOffset(categoryId);
    if (target == null || !_scroll.hasClients) return;

    _isProgrammaticScroll = true;
    final position = _scroll.position;
    await _scroll.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
    _isProgrammaticScroll = false;
  }

  /// Centra la pestaña activa moviendo solo la barra horizontal. `Scrollable.ensureVisible`
  /// también movería la carta (la barra está fija dentro de ella) y la devolvería hacia arriba.
  void _revealActiveTab() {
    final box = _tabKeys[_activeCategoryId]?.currentContext?.findRenderObject();
    if (box == null || !box.attached || !_tabsScroll.hasClients) return;

    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;

    final position = _tabsScroll.position;
    final target = viewport.getOffsetToReveal(box, 0.5).offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    _tabsScroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// La pestaña activa sigue a la categoría que se está viendo al hacer scroll.
  void _onScroll() {
    if (_isProgrammaticScroll || !_scroll.hasClients || !mounted) return;

    final current = _scroll.offset + 24;
    final groups = _productsByCategory;
    String? active;

    for (final group in groups) {
      final offset = _sectionOffset(group.category.id);
      if (offset == null) continue;
      if (offset <= current) {
        active = group.category.id;
      } else {
        break;
      }
    }

    active ??= groups.isEmpty ? null : groups.first.category.id;

    if (active != null && active != _activeCategoryId) {
      setState(() => _activeCategoryId = active);
      _revealActiveTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diner = context.watch<DinerStore>();
    final cart = context.watch<CartStore>();

    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SkeletonBlock(variant: 'list', rows: 5),
      );
    }

    if (_notice != null) {
      return SingleChildScrollView(
        child: DinerNotice(
          kind: _notice!,
          onRetry: _loadMenu,
          actions: [
            if (_notice != 'connection') BaseButton(label: 'Ver otras sedes', onPressed: () => context.go(Routes.home)),
          ],
        ),
      );
    }

    final site = _site;
    final canOrder = _canOrder(diner);
    final tableElsewhere = diner.isReadyToOrder && site != null && diner.restaurantId != site.id;
    final groups = _productsByCategory;
    final currency = _currency;
    final showCartBar = canOrder && cart.itemCount > 0;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadMenu(silent: true),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverList.list(
                  children: [
                    if (site != null) ...[
                      Text(site.cuisine.toUpperCase(), style: AppFonts.eyebrow(color: c.tertiary)),
                      const SizedBox(height: 4),
                      Text('La carta', style: AppFonts.headline(fontSize: 26, color: c.onSurface)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: c.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              site.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tableElsewhere) ...[
                      _TableElsewhereNote(
                        siteName: site.name,
                        tableRestaurant: diner.restaurantName,
                        onBack: () => context.go(diner.menuRoute),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (site != null)
                      MenuSearch(
                        controller: _search,
                        restaurantId: site.id,
                        categories: _categories,
                        products: _products,
                        currency: currency,
                        onSelectProduct: _openDetail,
                        onSelectCategory: _scrollToCategory,
                      ),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsDelegate(
                  categories: _categories,
                  activeId: _activeCategoryId,
                  tabKeys: _tabKeys,
                  controller: _tabsScroll,
                  onSelect: _scrollToCategory,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, showCartBar ? 104 : 32),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final group in groups)
                        Padding(
                          key: _sectionKeys[group.category.id],
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _CategorySection(
                            category: group.category,
                            items: group.items,
                            itemBuilder: (product) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MenuProductCard(
                                product: product,
                                quantity: cart.quantityOf(product.id),
                                currency: currency,
                                orderable: canOrder,
                                onIncrease: () => _increase(product),
                                onDecrease: () => _decrease(product),
                                onDetail: () => _openDetail(product),
                              ),
                            ),
                          ),
                        ),
                      if (groups.every((group) => group.items.isEmpty))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No encontramos productos con esa búsqueda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showCartBar)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Material(
                  color: c.primary,
                  elevation: 6,
                  shadowColor: Colors.black38,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go(Routes.cart),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.onPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${cart.itemCount}', style: AppFonts.label(fontSize: 14, color: c.onPrimary)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Ver carrito', style: AppFonts.label(fontSize: 16, color: c.onPrimary))),
                            Text(formatMoney(cart.subtotal, currency), style: AppFonts.label(fontSize: 16, color: c.onPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TableElsewhereNote extends StatelessWidget {
  const _TableElsewhereNote({required this.siteName, required this.tableRestaurant, required this.onBack});

  final String siteName;
  final String? tableRestaurant;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.qr_code_2_rounded, size: 20, color: c.onPrimaryFixed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
                    children: [
                      TextSpan(
                        text: 'Estás viendo la carta de $siteName. ',
                        style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                      ),
                      TextSpan(text: 'Tu mesa está en ${tableRestaurant ?? ''}.'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                    foregroundColor: c.onSurfaceVariant,
                  ),
                  child: const Text(
                    'Volver a tu mesa',
                    style: TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.items, required this.itemBuilder});

  final MenuCategory category;
  final List<MenuProduct> items;
  final Widget Function(MenuProduct product) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text(category.name, style: AppFonts.headline(fontSize: 20, color: c.onSurface))),
                  Text(
                    '${items.length} ${items.length == 1 ? 'opción' : 'opciones'}',
                    style: AppFonts.label(fontSize: 12, fontWeight: FontWeight.w500, color: c.outline),
                  ),
                ],
              ),
              if (category.description.isNotEmpty) Text(category.description, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            ],
          ),
        ),
        for (final product in items) itemBuilder(product),
      ],
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.categories, required this.activeId, required this.tabKeys, required this.controller, required this.onSelect});

  final List<MenuCategory> categories;
  final String? activeId;
  final Map<String, GlobalKey> tabKeys;
  final ScrollController controller;
  final ValueChanged<String> onSelect;

  @override
  double get minExtent => _tabsHeight;

  @override
  double get maxExtent => _tabsHeight;

  @override
  bool shouldRebuild(covariant _TabsDelegate oldDelegate) => oldDelegate.activeId != activeId || oldDelegate.categories != categories;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.colors;

    return Semantics(
      label: 'Categorías de la carta',
      container: true,
      child: Container(
        height: _tabsHeight,
        color: c.background.withValues(alpha: 0.96),
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final category in categories)
                Padding(
                  key: tabKeys[category.id],
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryTab(
                    label: category.name,
                    selected: category.id == activeId,
                    onTap: () => onSelect(category.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.onSurface : c.surfaceContainerLowest,
        shape: StadiumBorder(side: selected ? BorderSide.none : BorderSide(color: c.outlineVariant.withValues(alpha: 0.6))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(label, style: AppFonts.label(fontSize: 14, color: selected ? c.surface : c.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }
}
