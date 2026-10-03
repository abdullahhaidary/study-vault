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
                    if (value == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _EditQuestionSetScreen(set: set),
                        ),
                      );
                    }
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
                    PopupMenuItem(value: 'edit', child: Text('Edit questions')),
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

class _EditQuestionSetScreen extends ConsumerStatefulWidget {
  const _EditQuestionSetScreen({required this.set});

  final QuestionSet set;

  @override
  ConsumerState<_EditQuestionSetScreen> createState() =>
      _EditQuestionSetScreenState();
}

class _EditQuestionSetScreenState
    extends ConsumerState<_EditQuestionSetScreen> {
  late Future<List<QuizQuestion>> _questions;
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.set.title;
    _questions = ref
        .read(databaseProvider)
        .getQuizQuestionsForSet(widget.set.id);
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit quiz title'),
        content: TextField(controller: controller, maxLength: 300),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !mounted) return;
    try {
      await ref
          .read(databaseProvider)
          .updateQuestionSetTitle(widget.set.id, title);
      if (mounted) setState(() => _title = title);
    } on Object catch (_) {
      _showSaveError();
    }
  }

  Future<void> _editQuestion(QuizQuestion question) async {
    final db = ref.read(databaseProvider);
    final options = await db.getOptionsForQuestion(question.id);
    if (!mounted) return;
    final questionController = TextEditingController(text: question.question);
    final explanationController = TextEditingController(
      text: question.explanation,
    );
    final answerController = TextEditingController(
      text: question.correctAnswer,
    );
    final optionControllers = [
      for (final option in options)
        TextEditingController(text: option.optionText),
    ];
    var correctOptionId = options.where((o) => o.isCorrect).firstOrNull?.id;
    final edited =
        await showDialog<
          ({
            String question,
            String explanation,
            String answer,
            List<String> options,
            String? correctId,
          })
        >(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('Edit question ${question.position + 1}'),
              content: SizedBox(
                width: 560,
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: ListView(
                  children: [
                    TextField(
                      controller: questionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Question'),
                    ),
                    if (options.isEmpty)
                      TextField(
                        controller: answerController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Correct answer',
                        ),
                      )
                    else
                      RadioGroup<String>(
                        groupValue: correctOptionId,
                        onChanged: (id) =>
                            setDialogState(() => correctOptionId = id),
                        child: Column(
                          children: [
                            for (var i = 0; i < options.length; i++)
                              Row(
                                children: [
                                  Radio<String>(value: options[i].id),
                                  Expanded(
                                    child: TextField(
                                      controller: optionControllers[i],
                                      enabled: question.type == 'mcq',
                                      decoration: InputDecoration(
                                        labelText: 'Option ${i + 1}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: explanationController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Explanation',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final optionTexts = [
                      for (final c in optionControllers) c.text.trim(),
                    ];
                    if (questionController.text.trim().isEmpty ||
                        (options.isEmpty &&
                            answerController.text.trim().isEmpty) ||
                        optionTexts.any((text) => text.isEmpty) ||
                        (options.isNotEmpty && correctOptionId == null)) {
                      return;
                    }
                    final correctIndex = options.indexWhere(
                      (o) => o.id == correctOptionId,
                    );
                    Navigator.pop(context, (
                      question: questionController.text.trim(),
                      explanation: explanationController.text.trim(),
                      answer: options.isEmpty
                          ? answerController.text.trim()
                          : question.type == 'mcq'
                          ? '$correctIndex'
                          : optionTexts[correctIndex].toLowerCase(),
                      options: optionTexts,
                      correctId: correctOptionId,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
    questionController.dispose();
    explanationController.dispose();
    answerController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    if (edited == null || !mounted) return;
    try {
      await db.editQuizQuestion(
        original: question,
        question: edited.question,
        explanation: edited.explanation,
        answer: edited.answer,
        optionTexts: edited.options,
        correctOptionId: edited.correctId,
      );
      if (mounted) {
        setState(() => _questions = db.getQuizQuestionsForSet(widget.set.id));
      }
    } on Object catch (_) {
      _showSaveError();
    }
  }

  void _showSaveError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your changes.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit quiz')),
    body: FutureBuilder<List<QuizQuestion>>(
      future: _questions,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            ListTile(
              title: Text(_title),
              subtitle: const Text('Edit quiz title'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editTitle,
            ),
            for (final question in snapshot.data!)
              ListTile(
                title: Text(question.question),
                subtitle: Text(
                  'Question ${question.position + 1} · ${question.type}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editQuestion(question),
              ),
          ],
        );
      },
    ),
  );
}
