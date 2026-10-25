import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/book_providers.dart';
import '../domain/reading_plan.dart';
import 'book_actions.dart';

/// Chips for the book pages matched to a lecture; tap to read them.
class LectureBookLinks extends ConsumerWidget {
  const LectureBookLinks({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links =
        ref.watch(materialBookLinksProvider(materialId)).valueOrNull ??
        const [];
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 12, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (link, book) in links)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                link.done ? Icons.check : Icons.menu_book_outlined,
                size: 16,
              ),
              label: Text(
                '${book.title.length > 24 ? '${book.title.substring(0, 24)}…' : book.title} '
                'pp. ${link.startPage}–${link.endPage} · '
                '${BookLinkPriority.fromStorage(link.priority).label}',
              ),
              onPressed: () =>
                  openBookReader(context, book, page: link.startPage),
            ),
        ],
      ),
    );
  }
}

/// Compact list of the book page ranges linked to a material, for surfaces
/// like the AI study materials panel and sheet. Tap a row to open the book
/// at that page. Renders nothing when the material has no links.
///
/// Collapsed to a single header until expanded, so it does not keep a tall
/// block above an explanation. Close hides it until the screen is opened again.
class MaterialBookLinksSection extends ConsumerStatefulWidget {
  const MaterialBookLinksSection({super.key, required this.materialId});

  final String materialId;

  @override
  ConsumerState<MaterialBookLinksSection> createState() =>
      _MaterialBookLinksSectionState();
}

class _MaterialBookLinksSectionState
    extends ConsumerState<MaterialBookLinksSection> {
  bool _dismissed = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final links =
        ref.watch(materialBookLinksProvider(widget.materialId)).valueOrNull ??
        const [];
    if (links.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          title: Text(
            'Reference book pages',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _expanded ? 'Collapse' : 'Expand',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
              IconButton(
                tooltip: 'Hide',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
        if (_expanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 148),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final (link, book) in links)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      link.done ? Icons.check : Icons.menu_book_outlined,
                      size: 20,
                    ),
                    title: Text(
                      '${book.title} · pp. ${link.startPage}–${link.endPage} · '
                      '${BookLinkPriority.fromStorage(link.priority).label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: link.reason == null || link.reason!.isEmpty
                        ? null
                        : Text(
                            link.reason!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () =>
                        openBookReader(context, book, page: link.startPage),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
