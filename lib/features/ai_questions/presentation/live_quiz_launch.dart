import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/system_bottom_inset.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../domain/question_source.dart';
import '../domain/quiz_models.dart';
import 'generate_questions_sheet.dart';
import 'live_quiz_session_screen.dart';

/// Source + model picker for a live AI tutor session (no batch count/type).
Future<void> showLiveQuizLaunch(
  BuildContext context,
  WidgetRef ref, {
  required GenerateQuestionsLaunch launch,
}) async {
  final config = await showModalBottomSheet<_LiveQuizLaunchConfig>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _LiveQuizLaunchSheet(launch: launch),
  );
  if (config == null || !context.mounted) return;

  if (!await AiAssistantController.ensureReady(context, ref)) return;
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

  if (source.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No content available for that source.')),
    );
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LiveQuizSessionScreen(
        source: source,
        selection: config.selection,
      ),
    ),
  );
}

class _LiveQuizLaunchConfig {
  const _LiveQuizLaunchConfig({
    required this.sourceType,
    required this.selection,
  });

  final QuestionSourceType sourceType;
  final AiExecutionSelection selection;
}

class _LiveQuizLaunchSheet extends ConsumerStatefulWidget {
  const _LiveQuizLaunchSheet({required this.launch});

  final GenerateQuestionsLaunch launch;

  @override
  ConsumerState<_LiveQuizLaunchSheet> createState() =>
      _LiveQuizLaunchSheetState();
}

class _LiveQuizLaunchSheetState extends ConsumerState<_LiveQuizLaunchSheet> {
  late QuestionSourceType _source;
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
                widget.launch.title == 'Generate Questions'
                    ? 'Ask me questions'
                    : widget.launch.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'The AI asks one question at a time and grades your answer.',
                style: Theme.of(context).textTheme.bodyMedium,
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
                      onSelected: (_) => setState(() => _source = s),
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
                          _LiveQuizLaunchConfig(
                            sourceType: _source,
                            selection: _selection!,
                          ),
                        );
                      },
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
