import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/string.dart';

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 36});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.primaryFixed, shape: BoxShape.circle),
      child: name == null
          ? Icon(Icons.person_outline_rounded, color: c.onPrimaryFixed, size: size * 0.55)
          : Text(getInitials(name!), style: AppFonts.label(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: c.onPrimaryFixed)),
    );
  }
}
