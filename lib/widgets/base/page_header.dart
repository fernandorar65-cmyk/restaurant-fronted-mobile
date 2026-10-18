import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/restaurants/types.dart';
import '../../router/routes.dart';

/// Encabezado simple de una vista.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.description, this.child});

  final String title;
  final String? description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppFonts.headline(fontSize: 24, color: c.onSurface)),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(description!, style: TextStyle(color: c.onSurfaceVariant)),
        ],
        if (child != null) ...[const SizedBox(height: 8), child!],
      ],
    );
  }
}

/// Encabezado de las vistas de una sede: título, contexto y acciones.
class SitePageHeader extends StatelessWidget {
  const SitePageHeader({super.key, required this.restaurant, required this.section, required this.title, this.description, this.actions = const []});

  final RestaurantSite restaurant;
  final String section;
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${restaurant.name} · $section', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(title, style: AppFonts.headline(fontSize: 26, color: c.onSurface)),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: TextStyle(fontSize: 15, color: c.onSurfaceVariant)),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

/// Encabezado de las vistas de Administración, con miga hacia el inicio de administración.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.section, required this.title, this.description, this.actions = const []});

  final String section;
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => context.go(Routes.adminHome),
              child: Text('ADMINISTRACIÓN', style: AppFonts.eyebrow(color: c.onSurfaceVariant)),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(color: c.outlineVariant))),
            Flexible(child: Text(section.toUpperCase(), style: AppFonts.eyebrow(color: c.primary), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
        Text(title, style: AppFonts.headline(fontSize: 26, color: c.onSurface)),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: TextStyle(fontSize: 15, color: c.onSurfaceVariant)),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}
