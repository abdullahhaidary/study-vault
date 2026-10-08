import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../data/flashcards_providers.dart';

enum FlashcardsScopeType { all, subject, lesson }

class FlashcardsListScope {
  const FlashcardsListScope.all()
    : type = FlashcardsScopeType.all,
      id = null,
      title = 'Flashcards';
  const FlashcardsListScope.subject({required this.id, required this.title})
    : type = FlashcardsScopeType.subject;
  const FlashcardsListScope.lesson({required this.id, required this.title})
    : type = FlashcardsScopeType.lesson;

  final FlashcardsScopeType type;
  final String? id;
  final String title;
}

class FlashcardsListScreen extends ConsumerWidget {
  const FlashcardsListScreen({super.key, required this.scope});

  final FlashcardsListScope scope;

  AsyncValue<List<Flashcard>> _cards(WidgetRef ref) => switch (scope.type) {
    FlashcardsScopeType.all => ref.watch(allFlashcardsProvider),
    FlashcardsScopeType.subject => ref.watch(
      flashcardsForSubjectProvider(scope.id!),
    ),
    FlashcardsScopeType.lesson => ref.watch(
      flashcardsForLessonProvider(scope.id!),
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = _cards(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(scope.title),
        actions: [
          IconButton(
            tooltip: 'Study flashcards',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.flashcardStudy, arguments: scope),
          ),
        ],
      ),
      body: ScrollEdgeArrows(
        child: cards.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load flashcards: $error')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('No flashcards yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final card = items[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  title: Text(card.front),
                  subtitle: card.backPlainText == null
                      ? null
                      : Text(
                          card.backPlainText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  leading: const Icon(Icons.style_outlined),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit flashcard',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => _EditFlashcardDialog(card: card),
                        ),
                      ),
                      FavoriteStarButton(
                        entityType: 'flashcard',
                        entityId: card.id,
                      ),
                      IconButton(
                        tooltip: 'Delete flashcard',
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () async {
                          final confirmed = await confirmDelete(
                            context,
                            title: 'Delete flashcard?',
                            message:
                                '"${card.front}" will be permanently deleted.',
                          );
                          if (confirmed) {
                            await deleteFlashcard(ref, id: card.id);
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.flashcardStudy,
                    arguments: FlashcardsListScope.lesson(
                      id: card.lessonId!,
                      title: scope.title,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EditFlashcardDialog extends ConsumerStatefulWidget {
  const _EditFlashcardDialog({required this.card});

  final Flashcard card;

  @override
  ConsumerState<_EditFlashcardDialog> createState() =>
      _EditFlashcardDialogState();
}

class _EditFlashcardDialogState extends ConsumerState<_EditFlashcardDialog> {
  late final TextEditingController _front;
  late String _back;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.card.front);
    _back = widget.card.back;
  }

  @override
  void dispose() {
    _front.dispose();
    super.dispose();
  }

  Future<void> _editBack() async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            FullExplanationScreen(initialText: _back, title: 'Flashcard back'),
      ),
    );
    if (edited != null && mounted) setState(() => _back = edited);
  }

  Future<void> _save() async {
    if (_saving || _front.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await updateFlashcardContent(
        ref,
        card: widget.card,
        front: _front.text,
        back: _back,
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save flashcard.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit flashcard'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _front,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Front'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Back'),
            subtitle: Text(
              StudyNoteCodec.plainTextPreview(_back),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _saving ? null : _editBack,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}
