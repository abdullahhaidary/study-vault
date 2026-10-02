import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/system_bottom_inset.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../data/quiz_providers.dart';
import '../domain/question_source.dart';
import '../domain/quiz_models.dart';
import 'quiz_session_screen.dart';

/// Configuration for launching question generation from a study context.
class GenerateQuestionsLaunch {
  const GenerateQuestionsLaunch({
    required this.availableSources,
    required this.resolveSource,
    this.initialSource,
    this.title = 'Generate Questions',
  });

  final List<QuestionSourceType> availableSources;
  final QuestionSourceType? initialSource;
  final String title;

  /// Builds the normalized source for the selected type (may extract PDF text).
  final Future<QuestionSource> Function(QuestionSourceType type) resolveSource;
}

/// Shows the reusable question-generation configuration sheet, then runs
/// generation and opens Quiz Mode on success.
Future<void> showGenerateQuestionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required GenerateQuestionsLaunch launch,
}) async {
  final config = await showModalBottomSheet<_GenerateConfig>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _GenerateQuestionsSheet(launch: launch),
  );
  if (config == null || !context.mounted) return;

  if (!await AiAssistantController.ensureReady(
    context,
    ref,
    requireGemini: config.sendMode == AiPageSendMode.image,
  )) {
    return;
  }
  if (!context.mounted) return;

  QuestionSource source;
  try {
    source = await launch.resolveSource(config.sourceType);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not prepare source: $e')));
    return;
  }

  final allowEmpty = config.sendMode == AiPageSendMode.image;
  if (source.isEmpty && !allowEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No content available for that source.')),
    );
    return;
  }

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Generating questions…')),
          ],
        ),
      ),
    ),
  );

  try {
    final set = await ref
        .read(quizGenerationServiceProvider)
        .generateAndPersist(
          source: source,
          count: config.count,
          type: config.type,
          difficulty: config.difficulty,
          selection: config.selection,
          sendMode: config.sendMode,
        );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizSessionScreen(questionSetId: set.id),
      ),
    );
  } on AiException catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Question generation failed: $e')));
  }
}

class _GenerateConfig {
  const _GenerateConfig({
    required this.sourceType,
    required this.count,
    required this.type,
    required this.difficulty,
    required this.selection,
    this.sendMode = AiPageSendMode.text,
  });

  final QuestionSourceType sourceType;
  final int count;
  final QuizQuestionType type;
  final QuizDifficulty difficulty;
  final AiExecutionSelection selection;
  final AiPageSendMode sendMode;
}

class _GenerateQuestionsSheet extends ConsumerStatefulWidget {
  const _GenerateQuestionsSheet({required this.launch});

  final GenerateQuestionsLaunch launch;

  @override
  ConsumerState<_GenerateQuestionsSheet> createState() =>
      _GenerateQuestionsSheetState();
}

class _GenerateQuestionsSheetState
    extends ConsumerState<_GenerateQuestionsSheet> {
  late QuestionSourceType _source;
  int _count = 5;
  QuizQuestionType _type = QuizQuestionType.mixed;
  QuizDifficulty _difficulty = QuizDifficulty.mixed;
  AiPageSendMode _sendMode = AiPageSendMode.text;
  AiExecutionSelection? _selection;

  @override
  void initState() {
    super.initState();
    _source =
        widget.launch.initialSource ?? widget.launch.availableSources.first;
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final selection = await AiExecutionSelection.fromGlobal(
      ref.read(aiSettingsStoreProvider),
      action: AiStudyAction.generateQuestions,
    );
    if (!mounted) return;
    setState(() => _selection = selection);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = SystemBottomInset.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.launch.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Source', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in widget.launch.availableSources)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _source == s,
                      onSelected: (_) => setState(() {
                        _source = s;
                        if (s != QuestionSourceType.page) {
                          _sendMode = AiPageSendMode.text;
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_source == QuestionSourceType.page) ...[
                Text('Send as', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mode in AiPageSendMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: _sendMode == mode,
                        onSelected: (_) async {
                          setState(() => _sendMode = mode);
                          if (mode == AiPageSendMode.image) {
                            final global =
                                await AiExecutionSelection.fromGlobal(
                                  ref.read(aiSettingsStoreProvider),
                                  action: AiStudyAction.generateQuestions,
                                );
                            final geminiModel =
                                global.provider == AiProviderId.gemini
                                ? global.requestedModelId
                                : GeminiModelRegistry.defaultModelId;
                            if (!mounted) return;
                            setState(() {
                              _selection = AiExecutionSelection.resolve(
                                provider: AiProviderId.gemini,
                                requestedModelId: geminiModel,
                                action: AiStudyAction.generateQuestions,
                              );
                            });
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sendMode == AiPageSendMode.image
                      ? 'Sends a picture of this page (diagrams and slides). Uses Gemini.'
                      : 'Sends extracted text only (usually cheaper).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Number of questions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in kQuizQuestionCounts)
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _count == n,
                      onSelected: (_) => setState(() => _count = n),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Question type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in QuizQuestionType.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Difficulty', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in QuizDifficulty.values)
                    ChoiceChip(
                      label: Text(d.label),
                      selected: _difficulty == d,
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Model', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_selection == null)
                const LinearProgressIndicator()
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: AiModelPickerButton(
                    selection: _selection!,
                    action: AiStudyAction.generateQuestions,
                    constraints: _sendMode == AiPageSendMode.image
                        ? AiExecutionConstraints.vision
                        : AiExecutionConstraints.none,
                    onChanged: (AiExecutionSelection next) =>
                        setState(() => _selection = next),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _selection == null
                    ? null
                    : () {
                        Navigator.pop(
                          context,
                          _GenerateConfig(
                            sourceType: _source,
                            count: _count,
                            type: _type,
                            difficulty: _difficulty,
                            selection: _selection!,
                            sendMode: _source == QuestionSourceType.page
                                ? _sendMode
                                : AiPageSendMode.text,
                          ),
                        );
                      },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
