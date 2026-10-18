import 'package:flutter/material.dart';

/// Tokens de color del front web (`src/assets/main.css`), claro y oscuro.
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

  static const light = AppColors(
    background: Color(0xFFFAF9FA),
    surface: Color(0xFFFAF9FA),
    surfaceBright: Color(0xFFFAF9FA),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F3F4),
    surfaceContainer: Color(0xFFEFEDEE),
    surfaceContainerHigh: Color(0xFFE9E8E9),
    surfaceContainerHighest: Color(0xFFE3E2E3),
    surfaceDim: Color(0xFFDBDADB),
    onSurface: Color(0xFF1B1C1D),
    onSurfaceVariant: Color(0xFF434653),
    secondary: Color(0xFF5A5F63),
    secondaryContainer: Color(0xFFDFE3E8),
    onSecondaryContainer: Color(0xFF606569),
    outline: Color(0xFF737784),
    outlineVariant: Color(0xFFC3C6D5),
    primary: Color(0xFF094CB2),
    primaryContainer: Color(0xFF3366CC),
    onPrimary: Color(0xFFFFFFFF),
    onPrimaryContainer: Color(0xFFE7EBFF),
    tertiary: Color(0xFF6D5E00),
    tertiaryContainer: Color(0xFFBFAB49),
    onTertiaryContainer: Color(0xFF4A3F00),
    primaryFixed: Color(0xFFD9E2FF),
    primaryFixedDim: Color(0xFFB1C5FF),
    onPrimaryFixed: Color(0xFF001946),
    tertiaryFixed: Color(0xFFF9E37A),
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
  );

  static const dark = AppColors(
    background: Color(0xFF111316),
    surface: Color(0xFF16181C),
    surfaceBright: Color(0xFF2A2D33),
    surfaceContainerLowest: Color(0xFF1D2025),
    surfaceContainerLow: Color(0xFF22252B),
    surfaceContainer: Color(0xFF2A2D33),
    surfaceContainerHigh: Color(0xFF33373E),
    surfaceContainerHighest: Color(0xFF3D414A),
    surfaceDim: Color(0xFF111316),
    onSurface: Color(0xFFF1F1F4),
    onSurfaceVariant: Color(0xFFC4C7D2),
    secondary: Color(0xFFC3C7CC),
    secondaryContainer: Color(0xFF3F4448),
    onSecondaryContainer: Color(0xFFDFE3E8),
    outline: Color(0xFF8E919C),
    outlineVariant: Color(0xFF454955),
    primary: Color(0xFFA9C4FF),
    primaryContainer: Color(0xFF2F5FBF),
    onPrimary: Color(0xFF00255C),
    onPrimaryContainer: Color(0xFFDBE5FF),
    tertiary: Color(0xFFE3C757),
    tertiaryContainer: Color(0xFF8C7A1E),
    onTertiaryContainer: Color(0xFFFBE68A),
    primaryFixed: Color(0xFF23396A),
    primaryFixedDim: Color(0xFF5B7FD1),
    onPrimaryFixed: Color(0xFFDBE5FF),
    tertiaryFixed: Color(0xFF5A4B00),
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
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 || other is! AppColors ? this : other;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
