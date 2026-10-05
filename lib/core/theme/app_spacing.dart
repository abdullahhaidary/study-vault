import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Consistent spacing, radii, and layout breakpoints.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard page horizontal padding on phones.
  static const double pagePadding = 20;

  /// Horizontal padding on wide layouts.
  static const double pagePaddingWide = 32;

  /// Max readable content width for lists/forms.
  static const double contentMaxWidth = 840;

  /// Wide layout breakpoint (NavigationRail, denser toolbars).
  static const double wideBreakpoint = 720;

  static EdgeInsets pageInsets(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    return EdgeInsets.symmetric(
      horizontal: wide ? pagePaddingWide : pagePadding,
    );
  }

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  /// Window width at which desktop platforms use the desktop shell.
  static const double desktopBreakpoint = 1000;

  /// Max content width inside the desktop shell.
  static const double contentMaxWidthWide = 1280;

  static bool get isDesktopPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS => true,
    _ => false,
  };

  /// Desktop OS with a window wide enough for the desktop layout.
  static bool isDesktopLayout(BuildContext context) =>
      isDesktopPlatform &&
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static double contentWidth(BuildContext context) =>
      isDesktopLayout(context) ? contentMaxWidthWide : contentMaxWidth;
}

abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 12;

  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
}

/// Minimum interactive target size (accessibility).
abstract final class AppTouch {
  static const double min = 48;
}
