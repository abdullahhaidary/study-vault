import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../favorites/presentation/favorite_star_button.dart';
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
      body: cards.when(
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
                trailing: FavoriteStarButton(
                  entityType: 'flashcard',
                  entityId: card.id,
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
    );
  }
}
