import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/markdown/study_markdown.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/system_bottom_inset.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../data/quiz_providers.dart';
import '../domain/live_quiz_models.dart';
import '../domain/question_source.dart';

class LiveQuizSessionScreen extends ConsumerStatefulWidget {
  const LiveQuizSessionScreen({
    super.key,
    required this.source,
    required this.selection,
  });

  final QuestionSource source;
  final AiExecutionSelection selection;

  @override
  ConsumerState<LiveQuizSessionScreen> createState() =>
      _LiveQuizSessionScreenState();
}

class _LiveQuizSessionScreenState extends ConsumerState<LiveQuizSessionScreen> {
  final _answer = TextEditingController();
  LiveQuizSession? _session;
  String? _error;
  var _busy = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(liveQuizServiceProvider)
          .start(source: widget.source, selection: widget.selection);
      if (!mounted) return;
      setState(() {
        _session = session;
        _busy = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start the quiz.';
        _busy = false;
      });
    }
  }

  Future<void> _submit() async {
    final session = _session;
    if (session == null || _busy) return;
    if (_answer.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an answer first.')));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(liveQuizServiceProvider)
          .submitAnswer(session: session, answer: _answer.text);
      if (!mounted) return;
      _answer.clear();
      setState(() => _busy = false);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not grade that answer. Please try again.';
        _busy = false;
      });
    }
  }

  Future<void> _understood() async {
    final session = _session;
    if (session == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(liveQuizServiceProvider)
          .continueAfterUnderstood(session: session);
      if (!mounted) return;
      _answer.clear();
      setState(() => _busy = false);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not ask the next question. Please try again.';
        _busy = false;
      });
    }
  }

  void _end() {
    final session = _session;
    if (session != null) {
      ref.read(liveQuizServiceProvider).end(session);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final title = widget.source.referenceLabel ?? 'Ask me questions';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [TextButton(onPressed: _end, child: const Text('End'))],
      ),
      body: _buildBody(session),
      bottomNavigationBar: session == null
          ? null
          : SystemBottomSafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _bottomBar(session),
              ),
            ),
    );
  }

  Widget _buildBody(LiveQuizSession? session) {
    if (_busy && session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Could not start the quiz.'),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: _start, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final awaiting = session.phase == LiveQuizPhase.awaitingAnswer;
    final waitingOnAi = _busy || session.phase == LiveQuizPhase.asking;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (session.lastWasCorrect == true &&
            (session.lastFeedback ?? '').isNotEmpty) ...[
          _statusRow(correct: true, label: 'Correct'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            session.lastFeedback!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          'Question ${session.questionNumber}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          session.question,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _answer,
          enabled: awaiting && !waitingOnAi,
          decoration: const InputDecoration(
            labelText: 'Your answer',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
        ),
        if (session.phase == LiveQuizPhase.feedbackWrong) ...[
          const SizedBox(height: AppSpacing.md),
          _statusRow(correct: false, label: 'Incorrect'),
          const SizedBox(height: AppSpacing.sm),
          Text('From the source', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          StudyMarkdown(data: session.lastFeedback ?? ''),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (waitingOnAi) ...[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _statusRow({required bool correct, required String label}) {
    return Row(
      children: [
        Icon(
          correct ? Icons.check_circle : Icons.cancel,
          color: correct ? Colors.green : Colors.red,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }

  Widget _bottomBar(LiveQuizSession session) {
    final waitingOnAi = _busy || session.phase == LiveQuizPhase.asking;
    if (session.phase == LiveQuizPhase.feedbackWrong) {
      return FilledButton(
        onPressed: waitingOnAi ? null : _understood,
        child: const Text('Understood'),
      );
    }
    return FilledButton(
      onPressed: waitingOnAi || !session.canSubmit ? null : _submit,
      child: const Text('Submit'),
    );
  }
}
