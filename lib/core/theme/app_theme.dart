import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografías del front web: Poppins (texto), Noto Serif (títulos), Public Sans (etiquetas).
class AppFonts {
  AppFonts._();

  static TextStyle headline({double? fontSize, FontWeight fontWeight = FontWeight.w600, Color? color, double? height}) =>
      GoogleFonts.notoSerif(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

  static TextStyle label({double? fontSize, FontWeight fontWeight = FontWeight.w600, Color? color, double? letterSpacing}) =>
      GoogleFonts.publicSans(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);

  static TextStyle body({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) =>
      GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

  /// Etiqueta en mayúsculas con tracking amplio ("tracking-widest uppercase").
  static TextStyle eyebrow({Color? color, double fontSize = 11}) =>
      label(fontSize: fontSize, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.6);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.surface,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      tertiary: c.tertiary,
      onTertiary: c.surface,
      tertiaryContainer: c.tertiaryContainer,
      onTertiaryContainer: c.onTertiaryContainer,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceVariant,
      surfaceDim: c.surfaceDim,
      surfaceBright: c.surfaceBright,
      surfaceContainerLowest: c.surfaceContainerLowest,
      surfaceContainerLow: c.surfaceContainerLow,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainerHigh,
      surfaceContainerHighest: c.surfaceContainerHighest,
      outline: c.outline,
      outlineVariant: c.outlineVariant,
      inverseSurface: c.onSurface,
      onInverseSurface: c.surface,
    );

    final bodyFont = GoogleFonts.poppins().fontFamily;
    final baseText = ThemeData(brightness: brightness, fontFamily: bodyFont).textTheme.apply(
      bodyColor: c.onSurface,
      displayColor: c.onSurface,
    );

    final radius = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: bodyFont,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: baseText.copyWith(
        headlineLarge: AppFonts.headline(fontSize: 30, color: c.onSurface),
        headlineMedium: AppFonts.headline(fontSize: 26, color: c.onSurface),
        headlineSmall: AppFonts.headline(fontSize: 22, color: c.onSurface),
        titleLarge: AppFonts.headline(fontSize: 20, color: c.onSurface),
      ),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: AppFonts.headline(fontSize: 18, color: c.onSurface),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant.withValues(alpha: 0.6), thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: AppFonts.label(color: c.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: c.outline),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.error, width: 2)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceContainer,
        selectedColor: c.primaryFixed,
        labelStyle: AppFonts.label(fontSize: 13, color: c.onSurface),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.outlineVariant,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryFixed,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppFonts.label(
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? c.primary : c.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.primary : c.onSurfaceVariant),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: c.surfaceContainerLowest, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: c.onSurface),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}
