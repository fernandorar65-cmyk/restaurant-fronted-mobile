import 'package:flutter/material.dart';

/// Ícono Material equivalente a cada trazo de `expenseIcons` (sin SVG en la app móvil).
const Map<String, IconData> _expenseIconData = {
  'bag': Icons.shopping_bag_outlined,
  'people': Icons.people_outline_rounded,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_rounded,
  'wrench': Icons.build_outlined,
  'megaphone': Icons.campaign_outlined,
  'receipt': Icons.receipt_long_outlined,
  'dots': Icons.more_horiz_rounded,
  'truck': Icons.local_shipping_outlined,
  'sparkles': Icons.auto_awesome_outlined,
  'computer': Icons.computer_outlined,
  'shield': Icons.shield_outlined,
};

IconData expenseIconData(String? icon) => _expenseIconData[icon] ?? Icons.more_horiz_rounded;
