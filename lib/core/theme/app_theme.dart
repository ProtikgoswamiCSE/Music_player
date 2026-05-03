import 'package:flutter/material.dart';

/// Dark “aurora” palette — cohesive with gradients used in screens.
abstract final class AppColors {
  static const Color voidBlack = Color(0xFF070712);
  static const Color deepSpace = Color(0xFF12101F);
  static const Color violetGlow = Color(0xFF6C63FF);
  static const Color cyanAccent = Color(0xFF2DD4BF);
  static const Color roseAccent = Color(0xFFE879F9);
  static const Color surfaceGlass = Color(0x1AFFFFFF);
}

ThemeData buildAppTheme() {
  const seed = Color(0xFF5B4FFF);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: AppColors.violetGlow,
      secondary: AppColors.cyanAccent,
      tertiary: AppColors.roseAccent,
      surface: AppColors.deepSpace,
    ),
    scaffoldBackgroundColor: AppColors.voidBlack,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.deepSpace.withValues(alpha: 0.92),
      indicatorColor: AppColors.violetGlow.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.deepSpace,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.violetGlow,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white.withValues(alpha: 0.92),
      displayColor: Colors.white,
    ),
  );
}
