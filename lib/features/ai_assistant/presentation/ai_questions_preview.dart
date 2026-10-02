import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/system_bottom_inset.dart';
import '../domain/ai_models.dart';
import '../services/markdown_to_quill.dart';

Future<void> showAiQuestionsPreview(
  BuildContext context, {
  required AiQuestionsResult questions,
  Future<void> Function(AiQuestionsResult questions)? onDone,
  Future<void> Function(List<AiFlashcardDraft> cards)? onConvertToFlashcards,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AiQuestionsPreviewScreen(
        questions: questions,
        onDone: onDone,
        onConvertToFlashcards: onConvertToFlashcards,
      ),
    ),
  );
}

class AiQuestionsPreviewScreen extends StatelessWidget {
  const AiQuestionsPreviewScreen({
    super.key,
    required this.questions,
    this.onDone,
    this.onConvertToFlashcards,
  });

  final AiQuestionsResult questions;
  final Future<void> Function(AiQuestionsResult questions)? onDone;
  final Future<void> Function(List<AiFlashcardDraft> cards)?
  onConvertToFlashcards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study questions')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.questions.length,
        itemBuilder: (context, index) {
          final q = questions.questions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${index + 1}. ${q.question}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Answer: ${q.answer}'),
                  if (q.choices != null) ...[
                    const SizedBox(height: 8),
                    for (var i = 0; i < q.choices!.length; i++)
                      Text(
                        '${String.fromCharCode(65 + i)}. ${q.choices![i]}'
                        '${q.correctIndex == i ? ' ✓' : ''}',
                      ),
                  ],
                  if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      q.explanation!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SystemBottomSafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final buffer = StringBuffer();
                  for (var i = 0; i < questions.questions.length; i++) {
                    final q = questions.questions[i];
                    buffer.writeln('Q${i + 1}. ${q.question}');
                    buffer.writeln('A: ${q.answer}');
                    buffer.writeln();
                  }
                  await Clipboard.setData(
                    ClipboardData(text: buffer.toString()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copied')));
                  }
                },
                child: const Text('Copy'),
              ),
              if (onConvertToFlashcards != null)
                FilledButton(
                  onPressed: () async {
                    final cards = [
                      for (final q in questions.questions)
                        AiFlashcardDraft(
                          front: q.question,
                          back: MarkdownToQuill.toDeltaJson(q.answer),
                        ),
                    ];
                    await onConvertToFlashcards!(cards);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Convert to Flashcards'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
