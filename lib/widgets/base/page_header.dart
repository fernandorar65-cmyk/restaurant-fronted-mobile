import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/restaurants/types.dart';
import '../../router/routes.dart';

/// Título de página o de sección en 800 y `heading`. Si [accent] está, se agrega
/// después de [text] en `headingAccent` ("Tu **orden**").
class HeadingText extends StatelessWidget {
  const HeadingText(this.text, {super.key, this.accent, this.trailing, this.fontSize = 20, this.height, this.textAlign, this.color});

  final String text;
  final String? accent;

  /// Texto que sigue a la palabra destacada, de nuevo en `heading`.
  final String? trailing;
  final double fontSize;
  final double? height;
  final TextAlign? textAlign;

  /// Para títulos sobre bloques de color (por ejemplo `onDeep`).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppFonts.title(fontSize: fontSize, color: color ?? c.heading, height: height);

    if (accent == null) return Text(text, style: style, textAlign: textAlign);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          TextSpan(text: accent, style: TextStyle(color: c.headingAccent)),
          if (trailing != null) TextSpan(text: trailing),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Encabezado simple de una vista.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.accent, this.description, this.child});

  final String title;

  /// Palabra destacada en verde al final del título.
  final String? accent;
  final String? description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeadingText(title, accent: accent, fontSize: 30),
        if (description != null) ...[
          const SizedBox(height: 4),
          _Description(description!),
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
        Text(
          '${restaurant.name} · $section',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        HeadingText(title, fontSize: 30),
        if (description != null) ...[
          const SizedBox(height: 4),
          _Description(description!),
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
            Flexible(child: Text(section.toUpperCase(), style: AppFonts.eyebrow(color: c.primaryInk), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 8),
        HeadingText(title, fontSize: 30),
        if (description != null) ...[
          const SizedBox(height: 4),
          _Description(description!),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

/// Texto de apoyo bajo el título: corto, como en una app (máximo dos líneas).
class _Description extends StatelessWidget {
  const _Description(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, height: 1.35, color: context.colors.onSurfaceVariant),
      );
}
