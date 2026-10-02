import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Centers content and caps width for comfortable reading on large screens.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppSpacing.contentMaxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? AppSpacing.pageInsets(context),
          child: child,
        ),
      ),
    );
  }
}

/// Sliver variant of [ContentContainer].
class SliverContentPadding extends StatelessWidget {
  const SliverContentPadding({
    super.key,
    required this.sliver,
    this.padding,
    this.maxWidth = AppSpacing.contentMaxWidth,
    this.bottom = AppSpacing.xxl,
  });

  final Widget sliver;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final page = AppSpacing.pageInsets(context);
    final resolved =
        padding ?? EdgeInsets.fromLTRB(page.left, 0, page.right, bottom);

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final side = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
        final insets = resolved.add(EdgeInsets.symmetric(horizontal: side));
        return SliverPadding(padding: insets, sliver: sliver);
      },
    );
  }
}
