import 'package:flutter/material.dart';

enum DeviceScreenType { mobile, tablet, desktop }

class ResponsiveLayout {
  static const double mobileBreakpoint = 800.0;
  static const double desktopBreakpoint = 1100.0;
  static const double maxContentWidth = 1200.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return DeviceScreenType.desktop;
    if (width >= mobileBreakpoint) return DeviceScreenType.tablet;
    return DeviceScreenType.mobile;
  }

  static int getGridCrossAxisCount(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return mobile;
    if (width < desktopBreakpoint) return tablet;
    return desktop;
  }
}

/// Sizing information provided to [ResponsiveBuilder]
class ResponsiveInfo {
  final DeviceScreenType deviceScreenType;
  final Size screenSize;
  final Size localWidgetSize;
  final Orientation orientation;

  const ResponsiveInfo({
    required this.deviceScreenType,
    required this.screenSize,
    required this.localWidgetSize,
    required this.orientation,
  });

  bool get isMobile => deviceScreenType == DeviceScreenType.mobile;
  bool get isTablet => deviceScreenType == DeviceScreenType.tablet;
  bool get isDesktop => deviceScreenType == DeviceScreenType.desktop;
}

/// Reusable layout switcher that returns completely different widget trees for Mobile, Tablet, and Desktop.
/// Shares controllers, providers, and state models from parent scopes without duplicating logic.
class ScreenTypeLayout extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ScreenTypeLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= ResponsiveLayout.desktopBreakpoint) {
          if (desktop != null) return desktop!(context);
          if (tablet != null) return tablet!(context);
          return mobile(context);
        }
        if (width >= ResponsiveLayout.mobileBreakpoint) {
          if (tablet != null) return tablet!(context);
          return mobile(context);
        }
        return mobile(context);
      },
    );
  }
}

/// Dynamic widget builder exposing detailed screen and local widget constraints
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveInfo sizingInfo) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        DeviceScreenType type;
        if (width >= ResponsiveLayout.desktopBreakpoint) {
          type = DeviceScreenType.desktop;
        } else if (width >= ResponsiveLayout.mobileBreakpoint) {
          type = DeviceScreenType.tablet;
        } else {
          type = DeviceScreenType.mobile;
        }

        final info = ResponsiveInfo(
          deviceScreenType: type,
          screenSize: mediaQuery.size,
          localWidgetSize: Size(constraints.maxWidth, constraints.maxHeight),
          orientation: mediaQuery.orientation,
        );

        return builder(context, info);
      },
    );
  }
}

/// A container that centers its content and ensures comfortable max-width on wider desktop/web screens.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool fullWidthOnMobile;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.maxContentWidth,
    this.padding,
    this.fullWidthOnMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 28.0,
          vertical: isMobile ? 12.0 : 24.0,
        );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// Convenient BuildContext extensions for clean responsive code
extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveLayout.isMobile(this);
  bool get isTablet => ResponsiveLayout.isTablet(this);
  bool get isDesktop => ResponsiveLayout.isDesktop(this);
  bool get isWideDesktop => ResponsiveLayout.isWideDesktop(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
}
