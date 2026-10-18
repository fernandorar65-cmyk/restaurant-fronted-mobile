import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../stores/theme_store.dart';

/// Selector de tema: claro, oscuro o el del sistema.
class ThemeMenu extends StatelessWidget {
  const ThemeMenu({super.key});

  static const _options = [
    (value: 'light', label: 'Claro', icon: Icons.light_mode_outlined),
    (value: 'dark', label: 'Oscuro', icon: Icons.dark_mode_outlined),
    (value: 'system', label: 'Sistema', icon: Icons.brightness_auto_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeStore>();
    final current = _options.firstWhere((option) => option.value == theme.preference, orElse: () => _options.last);

    return PopupMenuButton<String>(
      tooltip: 'Tema',
      icon: Icon(current.icon),
      initialValue: theme.preference,
      onSelected: theme.setPreference,
      itemBuilder: (context) => [
        for (final option in _options)
          CheckedPopupMenuItem(
            value: option.value,
            checked: option.value == theme.preference,
            child: Row(children: [Icon(option.icon, size: 18), const SizedBox(width: 10), Text(option.label)]),
          ),
      ],
    );
  }
}
