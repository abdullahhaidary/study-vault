import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import '../data/quiz_providers.dart';
import '../domain/quiz_models.dart';
import 'quiz_session_screen.dart';

enum QuestionSetsScopeType { lesson, material }

class QuestionSetsScope {
  const QuestionSetsScope.lesson({required this.id, required this.title})
    : type = QuestionSetsScopeType.lesson;
  const QuestionSetsScope.material({required this.id, required this.title})
    : type = QuestionSetsScopeType.material;

  final QuestionSetsScopeType type;
  final String id;
  final String title;
}

class QuestionSetsScreen extends ConsumerWidget {
  const QuestionSetsScreen({super.key, required this.scope});

  final QuestionSetsScope scope;

  AsyncValue<List<QuestionSet>> _sets(WidgetRef ref) => switch (scope.type) {
    QuestionSetsScopeType.lesson => ref.watch(
      questionSetsForLessonProvider(scope.id),
    ),
    QuestionSetsScopeType.material => ref.watch(
      questionSetsForMaterialProvider(scope.id),
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = _sets(ref);
    return Scaffold(
      appBar: AppBar(title: Text('AI Questions · ${scope.title}')),
      body: sets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load quizzes: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No AI quizzes yet. Generate questions from a PDF or note.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final set = items[index];
              final type = QuizQuestionTypeX.fromStorage(set.questionType);
              final difficulty = QuizDifficultyX.fromStorage(set.difficulty);
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                title: Text(set.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${set.questionCount} questions · ${type.label} · ${difficulty.label}',
                    ),
                    if (aiTokenUsageFromColumns(
                          promptTokens: set.promptTokens,
                          completionTokens: set.completionTokens,
                          totalTokens: set.totalTokens,
                          cacheHitTokens: set.cacheHitTokens,
                          cacheMissTokens: set.cacheMissTokens,
                          model: set.aiModel,
                          provider: set.aiProvider,
                          durationMs: set.requestDurationMs,
                        )
                        case final usage?) ...[
                      const SizedBox(height: 4),
                      AiUsageIndicator(usage: usage),
                    ],
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete quiz?'),
                          content: const Text(
                            'This removes the question set and all attempts.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref
                            .read(databaseProvider)
                            .deleteQuestionSet(set.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizSessionScreen(questionSetId: set.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
