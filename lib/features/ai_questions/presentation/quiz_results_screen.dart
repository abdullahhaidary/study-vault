import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/quiz_models.dart';
import 'generate_questions_sheet.dart';
import 'quiz_session_screen.dart';

/// Results after submitting a quiz attempt.
class QuizResultsScreen extends ConsumerWidget {
  const QuizResultsScreen({
    super.key,
    required this.questionSetId,
    required this.attemptId,
    required this.score,
    this.onGenerateAnother,
  });

  final String questionSetId;
  final String attemptId;
  final QuizScore score;
  final VoidCallback? onGenerateAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz results')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '${score.percentage.round()}%',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Score: ${score.score} / 100',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          _StatTile(
            label: 'Correct',
            value: '${score.correctCount}',
            color: Colors.green,
          ),
          _StatTile(
            label: 'Incorrect',
            value: '${score.incorrectCount}',
            color: Colors.red,
          ),
          _StatTile(label: 'Total', value: '${score.totalQuestions}'),
          const SizedBox(height: 32),
          if (score.incorrectCount > 0) ...[
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizSessionScreen(
                      questionSetId: questionSetId,
                      existingAttemptId: attemptId,
                      reviewMistakesOnly: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Review mistakes'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final created = await createFlashcardsFromQuizMistakes(
                  ref,
                  questionSetId: questionSetId,
                  attemptId: attemptId,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      created == 0
                          ? 'No mistakes to convert.'
                          : 'Created $created flashcard${created == 1 ? '' : 's'}.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.style_outlined),
              label: const Text('Create Flashcards from Mistakes'),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      QuizSessionScreen(questionSetId: questionSetId),
                ),
              );
            },
            icon: const Icon(Icons.replay),
            label: const Text('Retry quiz'),
          ),
          const SizedBox(height: 8),
          if (onGenerateAnother != null)
            TextButton(
              onPressed: onGenerateAnother,
              child: const Text('Generate another quiz'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

/// Optional helper so callers can wire "Generate another" back to the sheet.
typedef GenerateAnotherQuiz = Future<void> Function();

/// Re-export for results callers that reopen the config sheet.
Future<void> reopenGenerateQuestions(
  BuildContext context,
  WidgetRef ref, {
  required GenerateQuestionsLaunch launch,
}) {
  return showGenerateQuestionsSheet(context, ref, launch: launch);
}
