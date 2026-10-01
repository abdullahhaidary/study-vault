import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/study_navigator.dart';
import '../../lessons/data/lesson_progress_providers.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.scope.title)),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load flashcards: $error')),
        data: (items) {
          if (items.isEmpty)
            return const Center(child: Text('No flashcards to study.'));
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
                      FilledButton(
                        onPressed: () {
                          if (_revealed)
                            _next(items.length);
                          else
                            setState(() => _revealed = true);
                          if (card.lessonId != null) {
                            recordLessonStudyActivity(
                              ref,
                              lessonId: card.lessonId!,
                            );
                          }
                        },
                        child: Text(_revealed ? 'Next' : 'Reveal'),
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
