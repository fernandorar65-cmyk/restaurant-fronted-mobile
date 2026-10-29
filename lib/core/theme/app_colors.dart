import 'package:flutter/material.dart';

/// Tokens de color de la app (estilo Spenza: verde esmeralda y azul petróleo), claro y oscuro.
/// Mismos valores que el front web (`src/assets/main.css`).
/// Uso: `context.colors.primary`, `context.colors.surfaceContainerLow`…
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceDim,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.tertiaryFixed,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.primaryInk,
    required this.heading,
    required this.headingAccent,
    required this.deep,
    required this.onDeep,
    required this.deepAccent,
  });

  final Color background;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceDim;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;
  final Color onPrimaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color tertiaryFixed;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  // Estados (siempre acompañados de ícono y texto, nunca solo color).
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  // [primary] solo sirve como relleno (2,15:1 sobre blanco); para texto, íconos y bordes en verde va [primaryInk].
  final Color primaryInk;
  // Títulos de página y de sección, y la palabra destacada en verde dentro de un título.
  final Color heading;
  final Color headingAccent;
  // Bloques azul petróleo: fondo, texto y acento verde sobre ese fondo.
  final Color deep;
  final Color onDeep;
  final Color deepAccent;

  // Estilo Spenza: verde esmeralda (solo relleno), azul petróleo y neutros limpios sin tinte.
  static const light = AppColors(
    background: Color(0xFFF6F8F8),
    surface: Color(0xFFF6F8F8),
    surfaceBright: Color(0xFFF6F8F8),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F3F3),
    surfaceContainer: Color(0xFFE9EEEE),
    surfaceContainerHigh: Color(0xFFE2E8E8),
    surfaceContainerHighest: Color(0xFFDBE2E3),
    surfaceDim: Color(0xFFD3DBDC),
    onSurface: Color(0xFF0F2430),
    onSurfaceVariant: Color(0xFF4A5C67),
    secondary: Color(0xFF4F6170),
    secondaryContainer: Color(0xFFDDE6E8),
    onSecondaryContainer: Color(0xFF3C4D57),
    outline: Color(0xFF6F7F86),
    outlineVariant: Color(0xFFCDD6D8),
    primary: Color(0xFF00CA83),
    primaryContainer: Color(0xFF00B373),
    onPrimary: Color(0xFF0B3549),
    onPrimaryContainer: Color(0xFF0B3549),
    tertiary: Color(0xFF9A5B00),
    tertiaryContainer: Color(0xFFF5B74E),
    onTertiaryContainer: Color(0xFF4A2C00),
    primaryFixed: Color(0xFFD4F7E8),
    primaryFixedDim: Color(0xFF7FE5BF),
    onPrimaryFixed: Color(0xFF00573A),
    tertiaryFixed: Color(0xFFFFE2B0),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    success: Color(0xFF1B6B3A),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD4F2DC),
    onSuccessContainer: Color(0xFF0B3D1D),
    warning: Color(0xFF8A5300),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE3B8),
    onWarningContainer: Color(0xFF4F2F00),
    primaryInk: Color(0xFF007A52),
    heading: Color(0xFF155983),
    headingAccent: Color(0xFF009E64),
    deep: Color(0xFF0B3549),
    onDeep: Color(0xFFFFFFFF),
    deepAccent: Color(0xFF00CA83),
  );

  static const dark = AppColors(
    background: Color(0xFF0F171C),
    surface: Color(0xFF131C22),
    surfaceBright: Color(0xFF2A3942),
    surfaceContainerLowest: Color(0xFF172128),
    surfaceContainerLow: Color(0xFF1C272E),
    surfaceContainer: Color(0xFF223038),
    surfaceContainerHigh: Color(0xFF2A3942),
    surfaceContainerHighest: Color(0xFF34444E),
    surfaceDim: Color(0xFF0F171C),
    onSurface: Color(0xFFEAF2F5),
    onSurfaceVariant: Color(0xFFBCCBD2),
    secondary: Color(0xFFB9C8D2),
    secondaryContainer: Color(0xFF2C3B44),
    onSecondaryContainer: Color(0xFFD8E5EA),
    outline: Color(0xFF87979F),
    outlineVariant: Color(0xFF3C4B54),
    primary: Color(0xFF00CA83),
    primaryContainer: Color(0xFF00B373),
    onPrimary: Color(0xFF0B3549),
    onPrimaryContainer: Color(0xFF0B3549),
    tertiary: Color(0xFFF2B95A),
    tertiaryContainer: Color(0xFF8A5A10),
    onTertiaryContainer: Color(0xFFFFDCA0),
    primaryFixed: Color(0xFF0B3B2B),
    primaryFixedDim: Color(0xFF00A56B),
    onPrimaryFixed: Color(0xFFB5F3D9),
    tertiaryFixed: Color(0xFF5A3C00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF5C1110),
    onErrorContainer: Color(0xFFFFDAD6),
    success: Color(0xFF8EE0A8),
    onSuccess: Color(0xFF00391A),
    successContainer: Color(0xFF134D29),
    onSuccessContainer: Color(0xFFC9F5D6),
    warning: Color(0xFFFFC66D),
    onWarning: Color(0xFF3A2400),
    warningContainer: Color(0xFF5A3A00),
    onWarningContainer: Color(0xFFFFE3B8),
    primaryInk: Color(0xFF00CA83),
    heading: Color(0xFFDCECF5),
    headingAccent: Color(0xFF00CA83),
    deep: Color(0xFF145A78),
    onDeep: Color(0xFFFFFFFF),
    deepAccent: Color(0xFF7FF5C8),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 || other is! AppColors ? this : other;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
