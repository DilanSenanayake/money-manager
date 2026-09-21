import 'package:flutter/material.dart';

class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const page = EdgeInsets.fromLTRB(20, 8, 20, 96);
  static const pageCompact = EdgeInsets.fromLTRB(20, 4, 20, 96);
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

class AppDuration {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const countUp = Duration(milliseconds: 780);
  static const shimmer = Duration(milliseconds: 1400);
}

class AppSize {
  static const touch = 44.0;
  static const navIcon = 22.0;
  static const navLabel = 12.0;
}

class AppElevation {
  static List<BoxShadow> soft(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get muted => colors.onSurfaceVariant;

  TextStyle get moneyHero => texts.headlineLarge!.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get moneyTitle => texts.headlineSmall!.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle navLabel({required bool selected}) => texts.labelSmall!.copyWith(
        fontSize: AppSize.navLabel,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: 0,
      );
}
