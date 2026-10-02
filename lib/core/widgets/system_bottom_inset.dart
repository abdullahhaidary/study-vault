import 'package:flutter/material.dart';

/// Keeps interactive UI above the system navigation / home indicator.
///
/// Prefer this for bottom-docked chrome. [MaterialApp] already applies a
/// bottom [SafeArea] globally; this helper remains useful for overlays that
/// also need keyboard inset via [MediaQuery.viewInsets].
abstract final class SystemBottomInset {
  /// Bottom padding that clears system nav and (optionally) the keyboard.
  static double of(
    BuildContext context, {
    bool includeKeyboard = true,
    double extra = 0,
  }) {
    final media = MediaQuery.of(context);
    final system = media.padding.bottom;
    final keyboard = includeKeyboard ? media.viewInsets.bottom : 0.0;
    return system + keyboard + extra;
  }
}

/// Pads only the bottom edge for the system navigation / home indicator.
class SystemBottomSafeArea extends StatelessWidget {
  const SystemBottomSafeArea({
    super.key,
    required this.child,
    this.minimum = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets minimum;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: minimum,
      child: child,
    );
  }
}
