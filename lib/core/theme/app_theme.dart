import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografías: todo usa la fuente del sistema (San Francisco en iOS, Roboto en Android)
/// para que se sienta como una app nativa; los títulos van en negrita.
class AppFonts {
  AppFonts._();

  static TextStyle headline({double? fontSize, FontWeight fontWeight = FontWeight.w700, Color? color, double? height}) =>
      TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: -0.3);

  static TextStyle label({double? fontSize, FontWeight fontWeight = FontWeight.w600, Color? color, double? letterSpacing}) =>
      TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);

  static TextStyle body({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) =>
      TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

  /// Etiqueta en mayúsculas con tracking ("tracking-widest uppercase").
  static TextStyle eyebrow({Color? color, double fontSize = 11}) =>
      label(fontSize: fontSize, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.2);
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

    final baseText = ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: c.onSurface,
      displayColor: c.onSurface,
    );

    final radius = BorderRadius.circular(14);
    final isCupertino = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const buttonSize = Size(48, 48);
    final buttonText = AppFonts.label(fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // En iPhone no hay "onda" al tocar (solo el resaltado), y las páginas entran deslizando.
      splashFactory: isCupertino ? NoSplash.splashFactory : InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: const PredictiveBackPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: c.background,
      textTheme: baseText.copyWith(
        headlineLarge: AppFonts.headline(fontSize: 28, color: c.onSurface),
        headlineMedium: AppFonts.headline(fontSize: 24, color: c.onSurface),
        headlineSmall: AppFonts.headline(fontSize: 20, color: c.onSurface),
        titleLarge: AppFonts.headline(fontSize: 18, color: c.onSurface),
      ),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        // Texto del sistema: los subtítulos de las barras no deben heredar la serif.
        titleTextStyle: AppFonts.label(fontSize: 17, color: c.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: buttonShape, textStyle: buttonText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: buttonSize, shape: buttonShape, textStyle: buttonText, elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: buttonText)),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        titleTextStyle: AppFonts.label(fontSize: 16, fontWeight: FontWeight.w500, color: c.onSurface),
        subtitleTextStyle: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: AppFonts.label(color: c.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: c.outline),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.outlineVariant.withValues(alpha: 0.6))),
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
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryFixed,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppFonts.label(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
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
