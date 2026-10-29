import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/string.dart';
import '../site_labels.dart';
import '../types.dart';

/// Integrante del personal en turno: iniciales, rol, área y estado.
class SiteStaffCard extends StatelessWidget {
  const SiteStaffCard({super.key, required this.member});

  final SiteStaffMember member;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color background, Color foreground) = switch (member.status) {
      'on-shift' => (c.primaryFixed, c.onPrimaryFixed),
      'break' => (c.tertiaryFixed, c.onTertiaryContainer),
      _ => (c.errorContainer, c.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 18,
              backgroundColor: c.primary,
              child: Text(getInitials(member.name), style: AppFonts.label(fontSize: 12, color: c.onPrimary)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                Text(
                  '${member.role} · ${staffAreaLabel[member.area] ?? member.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
            child: Text(
              (staffStatusLabel[member.status] ?? member.status).toUpperCase(),
              style: AppFonts.label(fontSize: 11, fontWeight: FontWeight.w700, color: foreground, letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
