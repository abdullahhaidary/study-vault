import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/material_storage.dart';
import '../../../core/widgets/system_bottom_inset.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../flashcards/data/flashcards_providers.dart';
import '../../lessons/data/materials_providers.dart';
import '../data/quiz_providers.dart';
import '../domain/quiz_models.dart';
import 'quiz_results_screen.dart';

/// Study Mode quiz: one question at a time with immediate check + explanation.
class QuizSessionScreen extends ConsumerStatefulWidget {
  const QuizSessionScreen({
    super.key,
    required this.questionSetId,
    this.reviewMistakesOnly = false,
    this.existingAttemptId,
  });

  final String questionSetId;
  final bool reviewMistakesOnly;
  final String? existingAttemptId;

  @override
  ConsumerState<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends ConsumerState<QuizSessionScreen> {
  List<QuizQuestionView> _questions = const [];
  String? _attemptId;
  var _index = 0;
  String? _selectedOptionId;
  final _textController = TextEditingController();
  bool? _checkedCorrect;
  var _loading = true;
  String? _error;
  final Map<String, _AnswerState> _answers = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final session = ref.read(quizSessionServiceProvider);
      var questions = await session.loadQuestions(widget.questionSetId);
      String attemptId;
      if (widget.existingAttemptId != null && widget.reviewMistakesOnly) {
        attemptId = widget.existingAttemptId!;
        questions = await session.loadIncorrectQuestions(attemptId);
      } else {
        final attempt = await session.startAttempt(
          questionSetId: widget.questionSetId,
        );
        attemptId = attempt.id;
      }
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _attemptId = attemptId;
        _loading = false;
        if (questions.isEmpty) {
          _error = 'No questions in this set.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not start quiz.';
      });
    }
  }

  QuizQuestionView get _current => _questions[_index];

  void _restoreCurrentAnswer() {
    final saved = _answers[_current.id];
    _selectedOptionId = saved?.selectedOptionId;
    _textController.text = saved?.answerText ?? '';
    _checkedCorrect = saved?.isCorrect;
  }

  Future<void> _checkAnswer() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;
    final q = _current;
    final needsOption =
        q.type == QuizQuestionType.mcq || q.type == QuizQuestionType.trueFalse;
    if (needsOption && _selectedOptionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an answer first.')));
      return;
    }
    if (!needsOption && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an answer first.')));
      return;
    }

    final correct = await ref
        .read(quizSessionServiceProvider)
        .recordAnswer(
          attemptId: attemptId,
          question: q,
          selectedOptionId: _selectedOptionId,
          answerText: _textController.text.trim().isEmpty
              ? null
              : _textController.text.trim(),
        );
    _answers[q.id] = _AnswerState(
      selectedOptionId: _selectedOptionId,
      answerText: _textController.text.trim(),
      isCorrect: correct,
    );
    if (!mounted) return;
    if (correct && _index < _questions.length - 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Correct')));
      setState(() {
        _index++;
        _restoreCurrentAnswer();
      });
      return;
    }
    setState(() => _checkedCorrect = correct);
  }

  void _understoodAndContinue() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _restoreCurrentAnswer();
      });
      return;
    }
    _submitQuiz();
  }

  Future<void> _submitQuiz() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;

    // Auto-check remaining unanswered if needed.
    for (final q in _questions) {
      if (_answers.containsKey(q.id)) continue;
      // Leave unanswered as incorrect by recording empty.
      final correct = await ref
          .read(quizSessionServiceProvider)
          .recordAnswer(
            attemptId: attemptId,
            question: q,
            selectedOptionId: null,
            answerText: '',
          );
      _answers[q.id] = _AnswerState(
        selectedOptionId: null,
        answerText: '',
        isCorrect: correct,
      );
    }

    final score = await ref
        .read(quizSessionServiceProvider)
        .completeAttempt(attemptId);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultsScreen(
          questionSetId: widget.questionSetId,
          attemptId: attemptId,
          score: score,
        ),
      ),
    );
  }

  Future<void> _goToSource() async {
    final q = _current;
    final materialId = q.materialId;
    final page = q.sourcePage;
    if (materialId == null || page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No source page for this question.')),
      );
      return;
    }
    final db = ref.read(databaseProvider);
    final material = await db.getMaterialById(materialId);
    if (material == null || !mounted) return;
    final path = await MaterialStorage.absolutePath(
      lessonId: material.lessonId,
      storedFileName: material.storedFileName,
    );
    if (!mounted) return;
    final route = isImageMimeType(material.mimeType)
        ? AppRoutes.imageStudy
        : AppRoutes.pdfStudy;
    await Navigator.of(context).pushNamed(
      route,
      arguments: <String, String>{
        'resourceId': material.id,
        'title': material.title,
        'filePath': path,
        'initialPage': '$page',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(questionSetByIdProvider(widget.questionSetId));
    final title = setAsync.valueOrNull?.title ?? 'Quiz';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(_error ?? 'No questions.')),
      );
    }

    final q = _current;
    final progress = (_index + 1) / _questions.length;
    final checked = _checkedCorrect != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Question ${_index + 1} of ${_questions.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            q.type.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(q.question, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          if (q.type == QuizQuestionType.mcq ||
              q.type == QuizQuestionType.trueFalse)
            ...q.options.map((o) {
              final selected = _selectedOptionId == o.id;
              Color? tileColor;
              if (checked) {
                if (o.isCorrect) {
                  tileColor = Colors.green.withValues(alpha: 0.15);
                } else if (selected && !o.isCorrect) {
                  tileColor = Colors.red.withValues(alpha: 0.15);
                }
              }
              return Card(
                color: tileColor,
                child: ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(o.text),
                  onTap: checked
                      ? null
                      : () => setState(() => _selectedOptionId = o.id),
                ),
              );
            })
          else
            TextField(
              controller: _textController,
              enabled: !checked,
              decoration: InputDecoration(
                labelText: q.type == QuizQuestionType.fillBlank
                    ? 'Fill in the blank'
                    : 'Your answer',
                border: const OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          if (checked) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _checkedCorrect == true ? Icons.check_circle : Icons.cancel,
                  color: _checkedCorrect == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _checkedCorrect == true ? 'Correct' : 'Incorrect',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            if ((q.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _checkedCorrect == true ? 'Explanation' : 'From the source',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(q.explanation!),
            ],
            if (q.type == QuizQuestionType.shortAnswer ||
                q.type == QuizQuestionType.fillBlank) ...[
              const SizedBox(height: 8),
              Text('Expected: ${q.correctAnswer}'),
            ],
            if (q.sourcePage != null) ...[
              const SizedBox(height: 12),
              Text('Source: Page/Slide ${q.sourcePage}'),
              TextButton.icon(
                onPressed: _goToSource,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Go to Source'),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SystemBottomSafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _index == 0
                    ? null
                    : () {
                        setState(() {
                          _index--;
                          _restoreCurrentAnswer();
                        });
                      },
                child: const Text('Previous'),
              ),
              const Spacer(),
              if (!checked)
                FilledButton(
                  onPressed: _checkAnswer,
                  child: const Text('Check'),
                )
              else if (_checkedCorrect == false)
                FilledButton(
                  onPressed: _understoodAndContinue,
                  child: Text(
                    _index < _questions.length - 1
                        ? 'Understood'
                        : 'Understood · finish',
                  ),
                )
              else if (_index < _questions.length - 1)
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _index++;
                      _restoreCurrentAnswer();
                    });
                  },
                  child: const Text('Next'),
                )
              else
                FilledButton(
                  onPressed: _submitQuiz,
                  child: const Text('Submit quiz'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerState {
  const _AnswerState({
    this.selectedOptionId,
    this.answerText,
    required this.isCorrect,
  });

  final String? selectedOptionId;
  final String? answerText;
  final bool isCorrect;
}

/// Creates flashcards from incorrect quiz questions (reuses flashcard API).
Future<int> createFlashcardsFromQuizMistakes(
  WidgetRef ref, {
  required String questionSetId,
  required String attemptId,
}) async {
  final session = ref.read(quizSessionServiceProvider);
  final mistakes = await session.loadIncorrectQuestions(attemptId);
  if (mistakes.isEmpty) return 0;

  final db = ref.read(databaseProvider);
  final set = await db.getQuestionSetById(questionSetId);
  final lessonId = set?.lessonId;
  final subjectId = set?.subjectId;

  var created = 0;
  for (final q in mistakes) {
    final back = StringBuffer(q.correctAnswer);
    if ((q.explanation ?? '').isNotEmpty) {
      back.writeln();
      back.writeln();
      back.write(q.explanation);
    }
    await createFlashcard(
      ref,
      lessonId: lessonId,
      subjectId: subjectId,
      front: q.question,
      back: MarkdownToQuill.toDeltaJson(back.toString()),
    );
    created++;
  }
  return created;
}
