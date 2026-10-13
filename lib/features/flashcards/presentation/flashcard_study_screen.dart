import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/study_navigator.dart';
import '../../lessons/data/lesson_progress_providers.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_schedule/domain/schedule_day.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../data/flashcards_providers.dart';
import 'flashcards_list_screen.dart';

class FlashcardStudyScreen extends ConsumerStatefulWidget {
  const FlashcardStudyScreen({super.key, required this.scope});

  final FlashcardsListScope scope;

  @override
  ConsumerState<FlashcardStudyScreen> createState() =>
      _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends ConsumerState<FlashcardStudyScreen> {
  final FocusNode _focus = FocusNode();
  var _index = 0;
  var _revealed = false;
  var _dueOnly = true;
  var _rating = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _next(int count) {
    if (count == 0) return;
    setState(() {
      _index = (_index + 1) % count;
      _revealed = false;
    });
  }

  Future<void> _rate(String cardId, ReviewRating rating, int count) async {
    if (_rating) return;
    setState(() => _rating = true);
    try {
      await ref.read(flashcardReviewRepositoryProvider).rate(cardId, rating);
      if (mounted) {
        if (_dueOnly) {
          setState(() => _revealed = false);
        } else {
          _next(count);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save review. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = switch (widget.scope.type) {
      FlashcardsScopeType.all => ref.watch(allFlashcardsProvider),
      FlashcardsScopeType.subject => ref.watch(
        flashcardsForSubjectProvider(widget.scope.id!),
      ),
      FlashcardsScopeType.lesson => ref.watch(
        flashcardsForLessonProvider(widget.scope.id!),
      ),
    };
    final reviews = ref.watch(flashcardReviewEventsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.scope.title)),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load flashcards: $error')),
        data: (allCards) {
          if (_dueOnly && !reviews.hasValue) {
            return reviews.hasError
                ? const Center(child: Text('Could not load review schedule.'))
                : const Center(child: CircularProgressIndicator());
          }
          final latest = latestFlashcardReviews(reviews.valueOrNull ?? []);
          final today = ScheduleDay.format(ScheduleDay.today());
          final items = _dueOnly
              ? allCards.where((card) {
                  final due = latest[card.id]?.dueOn;
                  return due == null || due.compareTo(today) <= 0;
                }).toList()
              : allCards;
          if (allCards.isEmpty) {
            return const Center(child: Text('No flashcards to study.'));
          }
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('All caught up for today.'),
                  TextButton(
                    onPressed: () => setState(() => _dueOnly = false),
                    child: const Text('Study all cards'),
                  ),
                ],
              ),
            );
          }
          final card = items[_index % items.length];
          return Focus(
            autofocus: true,
            focusNode: _focus,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.space) {
                setState(() => _revealed = !_revealed);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _next(items.length);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Due cards')),
                      ButtonSegment(value: false, label: Text('All cards')),
                    ],
                    selected: {_dueOnly},
                    onSelectionChanged: (selection) => setState(() {
                      _dueOnly = selection.first;
                      _index = 0;
                      _revealed = false;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text('${_index % items.length + 1} / ${items.length}'),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(28),
                          child: _revealed
                              ? StudyRichTextViewer(storedValue: card.back)
                              : Text(
                                  card.front,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (card.sourceStudyPinId != null)
                        OutlinedButton.icon(
                          onPressed: () => StudyNavigator.openSourcePin(
                            context,
                            ref,
                            pinId: card.sourceStudyPinId!,
                          ),
                          icon: const Icon(Icons.link),
                          label: const Text('Open Source'),
                        ),
                      if (!_revealed)
                        FilledButton(
                          onPressed: () {
                            setState(() => _revealed = true);
                            if (card.lessonId != null) {
                              recordLessonStudyActivity(
                                ref,
                                lessonId: card.lessonId!,
                              );
                            }
                          },
                          child: const Text('Reveal'),
                        )
                      else
                        for (final rating in ReviewRating.values)
                          FilledButton.tonal(
                            onPressed: _rating
                                ? null
                                : () => _rate(card.id, rating, items.length),
                            child: Text(rating.label),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
