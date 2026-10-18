import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/string.dart';
import '../api.dart';
import '../types.dart';
import 'menu_product_card.dart';

/// Buscador de la carta con sugerencias. Con el campo vacío muestra los recomendados
/// del chef y las categorías; con texto, sugerencias de la API (con debounce).
/// El texto vive en [controller] (el padre filtra la carta con él).
class MenuSearch extends StatefulWidget {
  const MenuSearch({
    super.key,
    required this.controller,
    required this.restaurantId,
    required this.categories,
    required this.products,
    required this.currency,
    required this.onSelectProduct,
    required this.onSelectCategory,
  });

  final TextEditingController controller;
  final String restaurantId;
  final List<MenuCategory> categories;

  /// Productos ya cargados de la carta: se usan para los recomendados con el campo vacío.
  final List<MenuProduct> products;
  final String currency;
  final ValueChanged<MenuProduct> onSelectProduct;
  final ValueChanged<String> onSelectCategory;

  @override
  State<MenuSearch> createState() => _MenuSearchState();
}

class _MenuSearchState extends State<MenuSearch> {
  static const _debounce = Duration(milliseconds: 200);

  final FocusNode _focus = FocusNode();
  bool _isOpen = false;
  bool _isSearching = false;
  bool _hasError = false;
  List<MenuProduct> _suggestions = [];
  Timer? _timer;
  int _requestSeq = 0;
  String _lastTerm = '';

  String get _term => widget.controller.text.trim();

  @override
  void initState() {
    super.initState();
    _lastTerm = _term;
    widget.controller.addListener(_onTextChanged);
    _focus.addListener(() {
      if (_focus.hasFocus) setState(() => _isOpen = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final value = _term;

    if (value == _lastTerm) {
      setState(() {});
      return;
    }

    _lastTerm = value;
    _timer?.cancel();

    if (value.isEmpty) {
      _requestSeq++;
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isOpen = true;
      _isSearching = true;
    });
    _timer = Timer(_debounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final seq = ++_requestSeq;
    setState(() {
      _isSearching = true;
      _hasError = false;
    });

    try {
      final result = await searchMenuSuggestions(widget.restaurantId, value);

      // Una respuesta vieja no pisa a una más reciente.
      if (mounted && seq == _requestSeq) {
        setState(() => _suggestions = result);
      }
    } catch (_) {
      if (mounted && seq == _requestSeq) {
        setState(() {
          _hasError = true;
          _suggestions = [];
        });
      }
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _close() {
    if (_isOpen) setState(() => _isOpen = false);
  }

  void _chooseProduct(MenuProduct product) {
    widget.onSelectProduct(product);
    widget.controller.clear();
    _focus.unfocus();
    _close();
  }

  void _chooseCategory(String categoryId) {
    widget.onSelectCategory(categoryId);
    widget.controller.clear();
    _focus.unfocus();
    _close();
  }

  List<MenuProduct> get _highlights =>
      widget.products.where((product) => product.isAvailable && product.tags.contains(chefTag)).take(4).toList();

  Map<String, String> get _categoryName => {for (final category in widget.categories) category.id: category.name};

  /// Parte el nombre en tramos para resaltar la coincidencia, ignorando tildes y mayúsculas.
  List<({String text, bool match})> _highlight(String text) {
    final needle = normalizeSearch(_term);
    final haystack = text.split('').map((char) {
      final normalized = normalizeSearch(char);
      return normalized.isEmpty ? char : normalized;
    }).join();
    final start = needle.isEmpty ? -1 : haystack.indexOf(needle);

    if (start == -1 || haystack.length != text.length) {
      return [(text: text, match: false)];
    }

    return [
      (text: text.substring(0, start), match: false),
      (text: text.substring(start, start + needle.length), match: true),
      (text: text.substring(start + needle.length), match: false),
    ].where((part) => part.text.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return TapRegion(
      onTapOutside: (_) {
        _focus.unfocus();
        _close();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onTap: () => setState(() => _isOpen = true),
            onSubmitted: (_) => _close(),
            style: TextStyle(fontSize: 16, color: c.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar un plato o bebida',
              fillColor: c.surfaceContainerLowest,
              prefixIcon: Icon(Icons.search_rounded, color: c.outline),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.outline)),
                    )
                  : widget.controller.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: Icon(Icons.close_rounded, color: c.outline),
                          onPressed: widget.controller.clear,
                        )
                      : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c.outlineVariant)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c.primary, width: 2)),
            ),
          ),
          if (_isOpen) ...[
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              decoration: BoxDecoration(
                color: c.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8))],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _term.isNotEmpty ? _suggestionItems(c) : _idleItems(c),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(AppColors c, String text, {double top = 4}) => Padding(
        padding: EdgeInsets.fromLTRB(16, top, 16, 8),
        child: Text(text.toUpperCase(), style: AppFonts.eyebrow(color: c.outline)),
      );

  Widget _productRow(AppColors c, MenuProduct product, {required Widget title, required String subtitle}) {
    return InkWell(
      onTap: () => _chooseProduct(product),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              MenuProductImage(url: product.imageUrl, width: 44, height: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(formatMoney(product.price, widget.currency), style: AppFonts.label(fontSize: 14, color: c.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _suggestionItems(AppColors c) {
    final names = _categoryName;
    // Solo se sugieren productos de categorías visibles en la carta.
    final visible = _suggestions.where((product) => names.containsKey(product.categoryId)).toList();

    return [
      _sectionLabel(c, 'Sugerencias'),
      if (_hasError)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('No pudimos buscar ahora. Inténtalo de nuevo.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        )
      else if (!_isSearching && visible.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('Sin resultados para “$_term”.', style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        ),
      for (final product in visible)
        _productRow(
          c,
          product,
          title: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, color: c.onSurface),
              children: [
                for (final part in _highlight(product.name))
                  TextSpan(
                    text: part.text,
                    style: part.match ? TextStyle(fontWeight: FontWeight.w600, color: c.primary) : null,
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: '${names[product.categoryId] ?? ''}${product.isAvailable ? '' : ' · Agotado'}',
        ),
    ];
  }

  List<Widget> _idleItems(AppColors c) {
    final names = _categoryName;
    final highlights = _highlights;

    return [
      if (highlights.isNotEmpty) ...[
        _sectionLabel(c, 'Recomendados'),
        for (final product in highlights)
          _productRow(
            c,
            product,
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurface),
            ),
            subtitle: names[product.categoryId] ?? '',
          ),
      ],
      _sectionLabel(c, 'Categorías', top: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in widget.categories)
              ActionChip(
                label: Text(category.name),
                labelStyle: AppFonts.label(fontSize: 14, color: c.onSurfaceVariant),
                backgroundColor: c.surfaceContainer,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onPressed: () => _chooseCategory(category.id),
              ),
          ],
        ),
      ),
    ];
  }
}
