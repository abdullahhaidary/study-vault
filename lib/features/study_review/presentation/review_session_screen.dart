import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/study_navigator.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/system_bottom_inset.dart';
import '../../search/domain/study_search_result.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../data/review_session_providers.dart';
import '../domain/review_models.dart';
import '../domain/study_review_item.dart';
import 'review_complete_screen.dart';

/// Active recall review card session.
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() =>
      _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final session = ref.read(activeReviewSessionProvider);
    if (session == null || session.completed) return true;
    if (session.latestRatings.isEmpty && !session.revealed) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End review session?'),
        content: const Text(
          'Your ratings so far are saved. You can leave and start a new '
          'session later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    return result == true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final session = ref.read(activeReviewSessionProvider);
    if (session == null || session.completed) return KeyEventResult.ignored;

    final notifier = ref.read(activeReviewSessionProvider.notifier);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      if (!session.revealed) {
        notifier.reveal();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      notifier.goPrevious();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      notifier.goNext();
      return KeyEventResult.handled;
    }
    if (session.revealed) {
      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1) {
        notifier.rate(ReviewRating.again);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.numpad2) {
        notifier.rate(ReviewRating.hard);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.numpad3) {
        notifier.rate(ReviewRating.good);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.numpad4) {
        notifier.rate(ReviewRating.easy);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openSource(StudyReviewItem item) async {
    await StudyNavigator.openEntity(
      context,
      ref,
      kind: StudyEntityKind.studyPin,
      id: item.studyPinId,
      materialId: item.materialId,
      materialTitle: item.materialTitle,
      mimeType: item.mimeType,
      pageNumber: item.pageNumber,
      focusPinId: item.studyPinId,
    );
    if (mounted) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeReviewSessionProvider);
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No active review session.')),
      );
    }

    if (session.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ReviewCompleteScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final item = session.currentItem;
    if (item == null) {
      return const Scaffold(body: Center(child: Text('Nothing to review.')));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          ref.read(activeReviewSessionProvider.notifier).clear();
          Navigator.of(context).pop();
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            title: Text(session.scope.title),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${session.progressNumber} / ${session.totalCount}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: session.totalCount == 0
                    ? 0
                    : session.progressNumber / session.totalCount,
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 820 : double.infinity,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      children: [
                        if (item.categoryName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              item.categoryName!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _PromptBody(item: item),
                        const SizedBox(height: 20),
                        Text(
                          item.isQuestionCategory ? '' : item.promptLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                        if (item.isQuestionCategory) ...[
                          AutoDirectionText(
                            item.shortText,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          [
                            if (item.pageNumber != null)
                              'Page ${item.pageNumber}',
                            item.materialTitle,
                          ].where((s) => s.isNotEmpty).join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!session.revealed)
                          Center(
                            child: FilledButton.icon(
                              onPressed: () => ref
                                  .read(activeReviewSessionProvider.notifier)
                                  .reveal(),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Reveal Answer'),
                            ),
                          )
                        else ...[
                          Text(
                            'Full Note',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!item.isQuestionCategory &&
                              item.shortText.trim().isNotEmpty &&
                              item.annotationType == StudyPinType.text) ...[
                            AutoDirectionText(
                              item.shortText,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (item.hasFullNote)
                            StudyRichTextViewer(storedValue: item.fullNote!)
                          else
                            AutoDirectionText(
                              item.shortText,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 28),
                          Text(
                            'How well did you remember it?',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          _RatingRow(
                            selected: session.currentRating,
                            onRate: (rating) => ref
                                .read(activeReviewSessionProvider.notifier)
                                .rate(rating),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SystemBottomSafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: session.currentIndex > 0
                                ? () => ref
                                      .read(
                                        activeReviewSessionProvider.notifier,
                                      )
                                      .goPrevious()
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Previous'),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openSource(item),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open Source'),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed:
                                session.latestRatings.containsKey(
                                  item.studyPinId,
                                )
                                ? () => ref
                                      .read(
                                        activeReviewSessionProvider.notifier,
                                      )
                                      .goNext()
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Next'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptBody extends StatelessWidget {
  const _PromptBody({required this.item});

  final StudyReviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (item.isQuestionCategory) {
      return const SizedBox.shrink();
    }

    if (item.annotationType == StudyPinType.text && item.hasSelectedText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Text',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.65,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AutoDirectionText(
                '"${item.selectedText!.trim()}"',
                style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
              ),
            ),
          ),
        ],
      );
    }

    return AutoDirectionText(
      item.shortText,
      style: theme.textTheme.headlineSmall?.copyWith(height: 1.3),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.onRate, this.selected});

  final ValueChanged<ReviewRating> onRate;
  final ReviewRating? selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrap = constraints.maxWidth < 480;
        final buttons = [
          for (final rating in ReviewRating.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tooltip(
                  message: rating.hint,
                  child: rankingButton(context, rating),
                ),
              ),
            ),
        ];

        if (wrap) {
          return Column(
            children: [
              Row(children: buttons.sublist(0, 2)),
              const SizedBox(height: 8),
              Row(children: buttons.sublist(2)),
            ],
          );
        }
        return Row(children: buttons);
      },
    );
  }

  Widget rankingButton(BuildContext context, ReviewRating rating) {
    final selectedHere = selected == rating;
    return FilledButton.tonal(
      onPressed: () => onRate(rating),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: selectedHere
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
      ),
      child: Text(rating.label),
    );
  }
}
