import 'package:flutter/material.dart';

/// Screen classification based on device width
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

class Responsive {
  /// Common breakpoint constants
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 960;
  static const double desktopBreakpoint = 1200;

  static const double maxFormWidth = 680;
  static const double maxDialogWidth = 580;
  static const double maxContentWidth = 1100;

  /// Checks if current screen is mobile (< 600dp)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Checks if current screen is tablet (>= 600dp and < 960dp)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Checks if current screen is desktop / large display (>= 960dp)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// Checks if device is tablet or wider (>= 600dp)
  static bool isTabletOrWider(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint;

  /// Checks if screen has enough wide space (>= 900dp) for split-screen POS terminal layout
  static bool isWideTerminal(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  /// Returns the current ScreenType
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return ScreenType.mobile;
    if (width < tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// Calculates dynamic columns for POS product catalog grid
  static int getGridColumns(
    BuildContext context, {
    int mobile = 2,
    int tabletPortrait = 3,
    int tabletLandscape = 4,
    int desktop = 5,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 420) return mobile;
    if (width < 600) return mobile;
    if (width < 850) return tabletPortrait;
    if (width < 1150) return tabletLandscape;
    return desktop;
  }

  /// Returns recommended childAspectRatio for product cards
  static double getProductCardAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 0.68;
    if (width < 900) return 0.72;
    return 0.76;
  }
}

/// A wrapper widget that centers content and limits width on tablets/desktops
/// while staying full-width on mobile screens.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxFormWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// Modal wrapper that ensures bottom sheets do not over-expand on tablet/desktop displays
class ResponsiveModalSheet extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeightRatio;

  const ResponsiveModalSheet({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxDialogWidth,
    this.maxHeightRatio = 0.90,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.of(context).size.height * maxHeightRatio,
        ),
        child: child,
      ),
    );
  }
}
