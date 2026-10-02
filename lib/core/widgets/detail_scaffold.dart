import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Shared collapsing detail page chrome for Class / Subject / Lesson screens.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.bodySlivers,
    this.description,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final List<Widget> bodySlivers;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDescription =
        description != null && description!.trim().isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            title: Text(title),
            actions: actions,
          ),
          if (hasDescription)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: AppSpacing.pageInsets(
                      context,
                    ).copyWith(top: 0, bottom: AppSpacing.md),
                    child: Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ...bodySlivers,
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Horizontal page padding + max width for detail list content.
class DetailContent extends StatelessWidget {
  const DetailContent({
    super.key,
    required this.child,
    this.bottom = AppSpacing.xxl,
  });

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final page = AppSpacing.pageInsets(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(page.left, 0, page.right, bottom),
          child: child,
        ),
      ),
    );
  }
}
