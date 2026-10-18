import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Bloque gris pulsante de carga.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.5).animate(_controller),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: context.colors.surfaceContainer, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Esqueleto de carga: tarjetas grises que anticipan el contenido.
/// variant: 'cards' | 'list' | 'page'
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.rows = 3, this.variant = 'cards'});

  final int rows;
  final String variant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (variant == 'page') ...[
            const Skeleton(height: 32, width: 220),
            const SizedBox(height: 12),
            const Skeleton(height: 16, width: 300),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                2,
                (index) => Expanded(
                  child: Padding(padding: EdgeInsets.only(right: index == 0 ? 12 : 0), child: const Skeleton(height: 100)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (var index = 0; index < rows; index++) ...[
            Skeleton(height: variant == 'list' ? 80 : 150, radius: 16),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
