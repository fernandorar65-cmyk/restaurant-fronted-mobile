import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/site_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../stores/session_store.dart';
import '../../../stores/toast_store.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/base/page_header.dart';
import '../../../widgets/base/skeleton_block.dart';
import '../../../widgets/feedback/confirm.dart';
import '../../restaurants/types.dart';
import '../api.dart';
import '../types.dart';
import '../widgets/menu_category_dialog.dart';
import '../widgets/menu_preview_dialog.dart';
import '../widgets/menu_product_card.dart' show MenuProductImage;
import '../widgets/menu_product_dialog.dart';

const Map<MenuStatus, String> _menuStatusLabels = {
  'draft': 'Borrador',
  'active': 'Activo',
  'inactive': 'Inactivo',
};

/// Gestión de la carta de una sede: menús, categorías y productos.
class SiteMenuView extends StatefulWidget {
  const SiteMenuView({super.key, required this.siteSlug});

  final String siteSlug;

  @override
  State<SiteMenuView> createState() => _SiteMenuViewState();
}

class _SiteMenuViewState extends State<SiteMenuView> {
  late final SiteContext _site = SiteContext(widget.siteSlug, session: context.read<SessionStore>(), onReady: _loadMenu);

  List<Menu> _menus = const [];
  String? _selectedMenuId;
  List<MenuCategory> _categories = const [];
  List<MenuProduct> _products = const [];
  String? _activeCategoryId;
  String? _actionError;
  final TextEditingController _newMenuName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _site.addListener(_onSiteChanged);
    unawaited(_site.load());
  }

  @override
  void didUpdateWidget(covariant SiteMenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteSlug != widget.siteSlug) unawaited(_site.setSlug(widget.siteSlug));
  }

  @override
  void dispose() {
    _site.removeListener(_onSiteChanged);
    _site.dispose();
    _newMenuName.dispose();
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMenu(RestaurantSite site) async {
    _actionError = null;
    final results = await Future.wait<Object>([
      fetchMenus(site.id),
      fetchMenuCategories(site.id),
      fetchMenuProducts(site.id),
    ]);
    _menus = results[0] as List<Menu>;
    _categories = results[1] as List<MenuCategory>;
    _products = results[2] as List<MenuProduct>;
    _selectedMenuId = _menus.where((menu) => menu.status == 'active').firstOrNull?.id ?? _menus.firstOrNull?.id;
  }

  // ── Derivados ──────────────────────────────────────────

  String get _currency => _site.currency;

  Menu? get _selectedMenu => _menus.where((menu) => menu.id == _selectedMenuId).firstOrNull;

  bool get _hasActiveMenu => _menus.any((menu) => menu.status == 'active');

  List<MenuCategory> get _visibleCategories => _categories.where((category) => category.menuId == _selectedMenuId).toList();

  List<MenuProduct> get _visibleProducts {
    final categoryIds = _visibleCategories.map((category) => category.id).toSet();
    final menuProducts = _products.where((product) => categoryIds.contains(product.categoryId)).toList();

    if (_activeCategoryId == null) return menuProducts;

    return menuProducts.where((product) => product.categoryId == _activeCategoryId).toList();
  }

  String _categoryName(String categoryId) =>
      _categories.where((category) => category.id == categoryId).firstOrNull?.name ?? 'Sin categoría';

  void _toastError(String title) => context.read<ToastStore>().show(title, message: 'Inténtalo de nuevo.', tone: 'error');

  // ── Acciones ───────────────────────────────────────────

  Future<void> _createMenu() async {
    final id = _site.restaurantId;
    final name = _newMenuName.text.trim();
    if (id == null || name.isEmpty) return;

    try {
      final created = await createMenu(id, name);
      if (!mounted) return;
      setState(() {
        _menus = [..._menus, created];
        _selectedMenuId = created.id;
        _newMenuName.clear();
      });
    } catch (_) {
      if (mounted) _toastError('No se pudo crear el menú');
    }
  }

  Future<void> _changeMenuStatus(Menu menu, MenuStatus status) async {
    try {
      final changed = await updateMenuStatus(menu, status);
      if (!mounted) return;
      setState(() {
        _menus = _menus.map((item) => changed.where((updated) => updated.id == item.id).firstOrNull ?? item).toList();
      });
    } catch (_) {
      if (mounted) _toastError('No se pudo cambiar el estado del menú');
    }
  }

  /// Cambio rápido desde la tarjeta, sin abrir el formulario.
  Future<void> _toggleProductFlag(MenuProduct product, String flag) async {
    final current = flag == 'isActive' ? product.isActive : product.isAvailable;

    try {
      final updated = await patchMenuProduct(product.id, {flag: !current});
      if (!mounted) return;
      setState(() => _products = _products.map((item) => item.id == updated.id ? updated : item).toList());
    } catch (_) {
      if (mounted) setState(() => _actionError = 'No se pudo actualizar el producto.');
    }
  }

  Future<void> _moveCategory(MenuCategory category, int delta) async {
    final ordered = [..._visibleCategories];
    final index = ordered.indexWhere((item) => item.id == category.id);
    final target = index + delta;

    if (index < 0 || target < 0 || target >= ordered.length) return;

    final swap = ordered[index];
    ordered[index] = ordered[target];
    ordered[target] = swap;

    try {
      final updated = await reorderMenuCategories(ordered);
      if (!mounted) return;
      setState(() {
        _categories = _categories.map((item) => updated.where((changed) => changed.id == item.id).firstOrNull ?? item).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
      });
    } catch (_) {
      if (mounted) _toastError('No se pudo reordenar la categoría');
    }
  }

  Future<void> _moveProduct(MenuProduct product, int delta) async {
    final ordered = _products.where((item) => item.categoryId == product.categoryId).toList();
    final index = ordered.indexWhere((item) => item.id == product.id);
    final target = index + delta;

    if (index < 0 || target < 0 || target >= ordered.length) return;

    final swap = ordered[index];
    ordered[index] = ordered[target];
    ordered[target] = swap;

    try {
      final updated = await reorderMenuProducts(ordered);
      if (!mounted) return;
      setState(() {
        _products = _products.map((item) => updated.where((changed) => changed.id == item.id).firstOrNull ?? item).toList()
          ..sort((a, b) {
            final byPosition = a.position.compareTo(b.position);
            return byPosition != 0 ? byPosition : a.name.compareTo(b.name);
          });
      });
    } catch (_) {
      if (mounted) _toastError('No se pudo reordenar el producto');
    }
  }

  void _openCategoryDialog(MenuCategory? category) {
    unawaited(MenuCategoryDialog.show(context, category: category, onSave: (draft) => _saveCategory(category, draft)));
  }

  Future<String?> _saveCategory(MenuCategory? editing, MenuCategoryDraft draft) async {
    final id = _site.restaurantId;
    final menuId = _selectedMenuId;
    if (id == null || menuId == null) return null;

    try {
      if (editing != null) {
        final updated = await updateMenuCategory(editing.id, draft);
        if (mounted) setState(() => _categories = _categories.map((category) => category.id == updated.id ? updated : category).toList());
      } else {
        final created = await createMenuCategory(id, menuId, draft, _visibleCategories.length + 1);
        if (mounted) setState(() => _categories = [..._categories, created]);
      }
      return null;
    } catch (_) {
      return 'No se pudo guardar la categoría.';
    }
  }

  Future<void> _removeCategory(MenuCategory category) async {
    final hasProducts = _products.any((product) => product.categoryId == category.id);

    if (hasProducts) {
      setState(() => _actionError = 'No se puede eliminar "${category.name}" porque tiene productos asociados.');
      return;
    }

    try {
      await deleteMenuCategory(category.id);
      if (!mounted) return;
      setState(() {
        _categories = _categories.where((item) => item.id != category.id).toList();
        if (_activeCategoryId == category.id) _activeCategoryId = null;
      });
    } catch (_) {
      if (mounted) _toastError('No se pudo eliminar la categoría');
    }
  }

  void _openProductDialog(MenuProduct? product) {
    unawaited(MenuProductDialog.show(
      context,
      product: product,
      categories: _visibleCategories,
      defaultCategoryId: _activeCategoryId,
      currency: _currency,
      onSave: (draft) => _saveProduct(product, draft),
    ));
  }

  Future<String?> _saveProduct(MenuProduct? editing, MenuProductDraft draft) async {
    final id = _site.restaurantId;
    if (id == null) return null;

    try {
      if (editing != null) {
        final updated = await updateMenuProduct(editing.id, draft);
        if (mounted) setState(() => _products = _products.map((product) => product.id == updated.id ? updated : product).toList());
      } else {
        final position = _products.where((product) => product.categoryId == draft.categoryId).length + 1;
        final created = await createMenuProduct(id, draft, position);
        if (mounted) setState(() => _products = [..._products, created]);
      }
      return null;
    } catch (_) {
      return 'No se pudo guardar el producto.';
    }
  }

  Future<void> _removeProduct(MenuProduct product) async {
    final accepted = await confirmAction(
      context,
      title: '¿Eliminar "${product.name}"?',
      message: 'Se borra de la carta. Si solo quieres ocultarlo por un tiempo, desmarca "Activo".',
      confirmLabel: 'Eliminar producto',
      tone: 'danger',
    );

    if (!accepted) return;

    try {
      await deleteMenuProduct(product.id);
      if (mounted) setState(() => _products = _products.where((item) => item.id != product.id).toList());
    } catch (_) {
      if (mounted) _toastError('No se pudo eliminar el producto');
    }
  }

  void _openPreview() {
    final menu = _selectedMenu;
    if (menu == null) return;

    unawaited(MenuPreviewDialog.show(
      context,
      menuName: '${menu.name} (${_menuStatusLabels[menu.status] ?? menu.status})',
      categories: _visibleCategories,
      products: _products,
      currency: _currency,
    ));
  }

  // ── UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final site = _site.restaurant;
    Widget body;

    if (_site.isLoading) {
      body = const SkeletonBlock(variant: 'page');
    } else if (_site.loadError != null && site == null) {
      body = _Notice(message: _site.loadError!, tone: 'error');
    } else if (site != null) {
      body = _buildContent(context, site);
    } else {
      body = const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _site.reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [body],
      ),
    );
  }

  Widget _buildContent(BuildContext context, RestaurantSite site) {
    final c = context.colors;
    final selectedMenu = _selectedMenu;
    final visibleCategories = _visibleCategories;
    final visibleProducts = _visibleProducts;
    final activeCategory = visibleCategories.where((category) => category.id == _activeCategoryId).firstOrNull;
    final error = _site.loadError ?? _actionError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SitePageHeader(
          restaurant: site,
          section: 'Menú',
          title: 'Gestión de menú',
          description: 'Organiza menús, categorías y productos de la carta de ${site.name}.',
          actions: [
            BaseButton(label: 'Vista previa', icon: Icons.visibility_outlined, disabled: selectedMenu == null, onPressed: _openPreview),
            BaseButton(label: '+ Categoría', onPressed: () => _openCategoryDialog(null)),
            BaseButton(label: '+ Producto', variant: 'primary', onPressed: () => _openProductDialog(null)),
          ],
        ),
        const SizedBox(height: 16),
        if (!_hasActiveMenu) ...[
          const _Notice(message: 'Esta sede no tiene ningún menú activo: los comensales verán la carta vacía.', tone: 'warning'),
          const SizedBox(height: 12),
        ],
        if (error != null) ...[
          _Notice(message: error, tone: 'error'),
          const SizedBox(height: 12),
        ],

        // Menú, estado y alta de menú
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('menu-$_selectedMenuId-${_menus.length}'),
                      initialValue: _selectedMenuId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Menú'),
                      items: [
                        for (final menu in _menus)
                          DropdownMenuItem(
                            value: menu.id,
                            child: Text('${menu.name} (${_menuStatusLabels[menu.status] ?? menu.status})', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setState(() => _selectedMenuId = value),
                    ),
                  ),
                  if (selectedMenu != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('status-${selectedMenu.id}-${selectedMenu.status}'),
                        initialValue: selectedMenu.status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: [
                          for (final entry in _menuStatusLabels.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                        ],
                        onChanged: (value) {
                          if (value != null && value != selectedMenu.status) unawaited(_changeMenuStatus(selectedMenu, value));
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newMenuName,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createMenu(),
                      decoration: const InputDecoration(hintText: 'Nombre del nuevo menú...', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BaseButton(label: '+ Menú', onPressed: _createMenu),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: const [
            TextSpan(text: 'El comensal solo ve el menú '),
            TextSpan(text: 'Activo', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' (uno por sede: al activar otro, el anterior pasa a inactivo).'),
          ]),
          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Filtro por categoría
        Semantics(
          label: 'Filtrar por categoría',
          container: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Todas (${visibleProducts.length})'),
                    selected: _activeCategoryId == null,
                    onSelected: (_) => setState(() => _activeCategoryId = null),
                  ),
                ),
                for (final category in visibleCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${category.name} (${_products.where((product) => product.categoryId == category.id).length})'),
                      selected: _activeCategoryId == category.id,
                      onSelected: (_) => setState(() => _activeCategoryId = category.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (activeCategory != null) ...[
          const SizedBox(height: 8),
          _CategoryToolbar(
            category: activeCategory,
            onMoveBefore: () => _moveCategory(activeCategory, -1),
            onMoveAfter: () => _moveCategory(activeCategory, 1),
            onEdit: () => _openCategoryDialog(activeCategory),
            onRemove: () => _removeCategory(activeCategory),
          ),
        ] else if (visibleCategories.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Elige una categoría para ordenarla, editarla o eliminarla.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),

        for (final product in visibleProducts) ...[
          _ProductTile(
            product: product,
            categoryName: _categoryName(product.categoryId),
            currency: _currency,
            onToggleActive: () => _toggleProductFlag(product, 'isActive'),
            onToggleAvailable: () => _toggleProductFlag(product, 'isAvailable'),
            onMoveUp: () => _moveProduct(product, -1),
            onMoveDown: () => _moveProduct(product, 1),
            onEdit: () => _openProductDialog(product),
            onRemove: () => _removeProduct(product),
          ),
          const SizedBox(height: 12),
        ],
        if (visibleProducts.isEmpty) Text('No hay productos en esta categoría.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
      ],
    );
  }
}

class _CategoryToolbar extends StatelessWidget {
  const _CategoryToolbar({
    required this.category,
    required this.onMoveBefore,
    required this.onMoveAfter,
    required this.onEdit,
    required this.onRemove,
  });

  final MenuCategory category;
  final VoidCallback onMoveBefore;
  final VoidCallback onMoveAfter;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.label(fontSize: 14, color: c.onSurface)),
          ),
          IconButton(tooltip: 'Mover ${category.name} antes', onPressed: onMoveBefore, icon: const Icon(Icons.arrow_back_rounded)),
          IconButton(tooltip: 'Mover ${category.name} después', onPressed: onMoveAfter, icon: const Icon(Icons.arrow_forward_rounded)),
          IconButton(tooltip: 'Editar categoría', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: 'Eliminar categoría', onPressed: onRemove, icon: Icon(Icons.delete_outline_rounded, color: c.error)),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.categoryName,
    required this.currency,
    required this.onToggleActive,
    required this.onToggleAvailable,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onRemove,
  });

  final MenuProduct product;
  final String categoryName;
  final String currency;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleAvailable;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget badge(String label, Color background, Color foreground) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: AppFonts.label(fontSize: 12, color: foreground)),
        );

    Widget flag(String label, bool value, VoidCallback onChanged) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onChanged,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(value: value, onChanged: (_) => onChanged()),
                Text(label, style: TextStyle(fontSize: 13, color: c.onSurface)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );

    return Opacity(
      opacity: product.isActive ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuProductImage(url: product.imageUrl, height: 112, width: double.infinity),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(categoryName.toUpperCase(), style: AppFonts.label(fontSize: 11, color: c.tertiary, letterSpacing: 0.6)),
                      Text(product.name, style: AppFonts.headline(fontSize: 15, color: c.onSurface)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatMoney(product.price, currency), style: AppFonts.label(fontSize: 14, fontWeight: FontWeight.w700, color: c.primaryInk)),
              ],
            ),
            if (product.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(product.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in product.tags) badge(tag, c.primaryFixed, c.onPrimaryFixed),
                if (!product.isActive)
                  badge('OCULTO', c.surfaceContainerHigh, c.onSurfaceVariant)
                else if (!product.isAvailable)
                  badge('AGOTADO', c.errorContainer, c.onErrorContainer),
              ],
            ),
            Wrap(
              children: [
                flag('Activo', product.isActive, onToggleActive),
                flag('Disponible', product.isAvailable, onToggleAvailable),
              ],
            ),
            Divider(color: c.outlineVariant.withValues(alpha: 0.5)),
            Row(
              children: [
                IconButton(tooltip: 'Subir ${product.name}', onPressed: onMoveUp, icon: const Icon(Icons.arrow_upward_rounded)),
                IconButton(tooltip: 'Bajar ${product.name}', onPressed: onMoveDown, icon: const Icon(Icons.arrow_downward_rounded)),
                const Spacer(),
                BaseButton(label: 'Editar', size: 'sm', onPressed: onEdit),
                const SizedBox(width: 8),
                BaseButton(label: 'Eliminar', size: 'sm', variant: 'danger-soft', onPressed: onRemove),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso en línea. tone: 'error' | 'warning'.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.tone});

  final String message;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isError = tone == 'error';

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isError ? c.errorContainer : c.tertiaryFixed, borderRadius: BorderRadius.circular(8)),
        child: Text(message, style: TextStyle(fontSize: 14, color: isError ? c.onErrorContainer : c.onTertiaryContainer)),
      ),
    );
  }
}
