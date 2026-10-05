import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/markdown/chart_markdown_builder.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../ai_assistant/services/quill_to_markdown.dart';
import '../../manual_entry/data/manual_entry_providers.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../data/course_review_providers.dart';
import '../domain/course_review_models.dart';
import '../domain/course_review_prompts.dart';

/// Subject-wide condensed review: one section per PDF plus course-wide
/// examples and a big picture.
class CourseReviewScreen extends ConsumerStatefulWidget {
  const CourseReviewScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<CourseReviewScreen> createState() => _CourseReviewScreenState();
}

class _CourseReviewScreenState extends ConsumerState<CourseReviewScreen> {
  static const _readingParts = [
    CourseReviewPart.summary,
    CourseReviewPart.explanation,
    CourseReviewPart.deepExplanation,
    CourseReviewPart.examples,
  ];

  bool _busy = false;
  bool _stopRequested = false;
  String? _progress;
  double? _progressValue;
  int _exampleCount = CourseReviewPrompts.defaultExampleCount;
  final _sectionKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(courseReviewProvider(widget.subjectId));
    return async.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: const AppErrorState(message: 'Could not load the Course Review.'),
      ),
      data: (state) {
        if (state == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorState(message: 'Subject not found'),
          );
        }
        return DefaultTabController(
          length: 1 + _readingParts.length,
          initialIndex: state.isEmpty ? 0 : 1,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Course Review'),
                  Text(
                    state.subject.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Import JSON',
                  icon: const Icon(Icons.data_object),
                  onPressed: _busy ? null : _openImport,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Copy for an external AI',
                  icon: const Icon(Icons.copy_all_outlined),
                  onSelected: (v) => v == 'sections'
                      ? _copySectionsPrompt(state)
                      : _copyOverviewRequest(state),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'sections',
                      child: Text('Copy prompt for lecture sections'),
                    ),
                    PopupMenuItem(
                      value: 'overview',
                      child: Text('Copy request for examples & big picture'),
                    ),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'Lectures'),
                  for (final part in _readingParts) Tab(text: part.label),
                ],
              ),
            ),
            body: Column(
              children: [
                if (_progress != null) _progressBanner(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _lecturesTab(state),
                      for (final part in _readingParts) _readingTab(state, part),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Layout helpers ───────────────────────────────────────

  Widget _page(List<Widget> children) {
    return ListView(
      padding: AppSpacing.pageInsets(
        context,
      ).copyWith(top: AppSpacing.md, bottom: 96),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppSpacing.contentWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressBanner() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Column(
        children: [
          LinearProgressIndicator(value: _progressValue),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _progress!,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (_busy && _progressValue != null)
                  TextButton(
                    onPressed: _stopRequested
                        ? null
                        : () => setState(() => _stopRequested = true),
                    child: Text(_stopRequested ? 'Stopping…' : 'Stop after this'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lectures tab ─────────────────────────────────────────

  Widget _lecturesTab(CourseReviewState state) {
    final theme = Theme.of(context);
    if (state.sources.isEmpty) {
      return const EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: 'No PDFs in this subject yet',
        message: 'Attach lecture PDFs to lessons, then build the review here.',
      );
    }
    final missing = state.sources
        .where((s) => s.status == CourseReviewSourceStatus.notAdded)
        .toList();
    final outdated = state.sources
        .where((s) => s.status == CourseReviewSourceStatus.outdated)
        .toList();
    return _page([
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${state.withSections.length} of ${state.included.length} '
                'lectures added',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Each lecture is one AI request, built from its lesson '
                'Summary/Explanation when available, otherwise the PDF text. '
                'You can also import sections as JSON.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || missing.isEmpty
                        ? null
                        : () => _generateSections(missing),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text('Generate missing (${missing.length})'),
                  ),
                  if (outdated.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _generateSections(outdated),
                      icon: const Icon(Icons.refresh),
                      label: Text('Refresh outdated (${outdated.length})'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy || state.withSections.isEmpty
                        ? null
                        : () => _generateOverview(),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text(
                      state.overview.isEmpty
                          ? 'Generate examples & big picture'
                          : state.overviewOutdated
                          ? 'Update examples & big picture'
                          : 'Regenerate examples & big picture',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openImport,
                    icon: const Icon(Icons.data_object),
                    label: const Text('Import JSON'),
                  ),
                ],
              ),
              if (state.overviewOutdated)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Lectures changed since the examples and big picture were '
                    'made.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final source in state.sources) _sourceTile(source),
    ]);
  }

  Widget _sourceTile(CourseReviewSource source) {
    final theme = Theme.of(context);
    final status = source.status;
    final (icon, color) = switch (status) {
      CourseReviewSourceStatus.added => (
        Icons.check_circle,
        theme.colorScheme.primary,
      ),
      CourseReviewSourceStatus.outdated => (
        Icons.update,
        theme.colorScheme.tertiary,
      ),
      CourseReviewSourceStatus.notAdded => (
        Icons.radio_button_unchecked,
        theme.colorScheme.outline,
      ),
      CourseReviewSourceStatus.excluded => (
        Icons.block,
        theme.colorScheme.outline,
      ),
    };
    final version = source.latest[CourseReviewPart.summary]?.version;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          source.material.title,
          style: status == CourseReviewSourceStatus.excluded
              ? TextStyle(color: theme.colorScheme.outline)
              : null,
        ),
        subtitle: Text(
          [
            source.lesson.name,
            status.label + (version == null ? '' : ' · v$version'),
            if (!source.excluded)
              source.usesLessonMaterials
                  ? 'from lesson materials'
                  : 'from PDF text',
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          enabled: !_busy,
          onSelected: (v) => _onSourceAction(source, v),
          itemBuilder: (_) => [
            if (!source.excluded)
              PopupMenuItem(
                value: 'generate',
                child: Text(
                  source.hasSection ? 'Regenerate section' : 'Generate section',
                ),
              ),
            for (final part in CourseReviewPart.sectionParts)
              if (source.latest[part] != null)
                PopupMenuItem(
                  value: 'edit:${part.storageValue}',
                  child: Text('Edit ${part.label.toLowerCase()}'),
                ),
            PopupMenuItem(
              value: source.excluded ? 'include' : 'exclude',
              child: Text(
                source.excluded ? 'Include in review' : 'Exclude from review',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSourceAction(CourseReviewSource source, String action) async {
    final service = ref.read(courseReviewServiceProvider);
    switch (action) {
      case 'generate':
        await _generateSections([source]);
      case 'include' || 'exclude':
        await service.setExcluded(source, action == 'exclude');
      default:
        final part = CourseReviewPart.fromStorage(action.substring(5))!;
        await _edit(source.latest[part]!, part);
    }
  }

  // ── Reading tabs ─────────────────────────────────────────

  Widget _readingTab(CourseReviewState state, CourseReviewPart part) {
    final theme = Theme.of(context);
    final style = MarkdownStyleSheet.fromTheme(theme);
    if (part == CourseReviewPart.examples) {
      final entry = state.overview[CourseReviewPart.examples];
      if (entry == null) {
        return EmptyState(
          icon: Icons.lightbulb_outline,
          title: 'No examples yet',
          message:
              'Create about $_exampleCount short examples across the whole '
              'course from the added lectures, or import them as JSON.',
          action: FilledButton.icon(
            onPressed: _busy || state.withSections.isEmpty
                ? null
                : _generateOverview,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate examples'),
          ),
        );
      }
      return SelectionArea(
        child: _page([
          _entryHeader(
            title: 'Course examples',
            entry: entry,
            part: part,
            outdated: entry.sourceFingerprint != state.overviewFingerprint,
          ),
          _markdown(entry.content, style),
        ]),
      );
    }

    final sources = state.withSections
        .where((s) => s.latest[part] != null)
        .toList();
    final bigPicture = part == CourseReviewPart.summary
        ? state.overview[CourseReviewPart.bigPicture]
        : null;
    if (sources.isEmpty && bigPicture == null) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'Nothing here yet',
        message:
            'Generate or import lecture sections from the Lectures tab to '
            'build the ${part.label.toLowerCase()}.',
        action: OutlinedButton(
          onPressed: () => DefaultTabController.of(context).animateTo(0),
          child: const Text('Open Lectures'),
        ),
      );
    }
    final notAdded = state.count(CourseReviewSourceStatus.notAdded);
    return SelectionArea(
      child: _page([
        if (sources.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final s in sources)
                  ActionChip(
                    label: Text(s.material.title),
                    onPressed: () {
                      final target = _key(part, s.material.id).currentContext;
                      if (target != null) {
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 300),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        if (bigPicture != null) ...[
          _entryHeader(
            title: 'Big picture',
            entry: bigPicture,
            part: CourseReviewPart.bigPicture,
            outdated: bigPicture.sourceFingerprint != state.overviewFingerprint,
          ),
          _markdown(bigPicture.content, style),
          const Divider(height: AppSpacing.xl),
        ],
        for (final s in sources) ...[
          KeyedSubtree(
            key: _key(part, s.material.id),
            child: _entryHeader(
              title: s.material.title,
              subtitle: s.lesson.name,
              entry: s.latest[part]!,
              part: part,
              outdated: s.status == CourseReviewSourceStatus.outdated,
            ),
          ),
          _markdown(s.latest[part]!.content, style),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (notAdded > 0)
          Text(
            '$notAdded lecture(s) not added yet — see the Lectures tab.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ]),
    );
  }

  GlobalKey _key(CourseReviewPart part, String materialId) => _sectionKeys
      .putIfAbsent('${part.storageValue}:$materialId', GlobalKey.new);

  Widget _markdown(String content, MarkdownStyleSheet style) => MarkdownBody(
    data: content,
    styleSheet: style,
    builders: chartMarkdownBuilders(style),
  );

  Widget _entryHeader({
    required String title,
    String? subtitle,
    required CourseReviewEntry entry,
    required CourseReviewPart part,
    required bool outdated,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    ?subtitle,
                    'v${entry.version}',
                    if (outdated) 'Outdated',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: outdated
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _busy ? null : () => _edit(entry, part),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────

  Future<AiExecutionSelection?> _pickModel(String title) async {
    if (!await AiAssistantController.ensureReady(context, ref)) return null;
    if (!mounted) return null;
    final selection = await AiExecutionSelection.fromGlobal(
      ref.read(aiSettingsStoreProvider),
      action: AiStudyAction.customPrompt,
    );
    if (!mounted) return null;
    return await showAiModelSelector(
          context,
          selected: selection,
          action: AiStudyAction.customPrompt,
          title: title,
        ) ??
        selection;
  }

  Future<void> _generateSections(List<CourseReviewSource> sources) async {
    if (_busy || sources.isEmpty) return;
    final selection = await _pickModel(
      sources.length == 1
          ? 'Generate review section with'
          : 'Generate ${sources.length} review sections with',
    );
    if (selection == null || !mounted) return;
    final service = ref.read(courseReviewServiceProvider);
    final failures = <String>[];
    var done = 0;
    setState(() {
      _busy = true;
      _stopRequested = false;
    });
    try {
      for (var i = 0; i < sources.length; i++) {
        if (_stopRequested) break;
        final source = sources[i];
        _setProgress(
          'Generating ${i + 1} of ${sources.length}: ${source.material.title}',
          sources.length == 1 ? null : i / sources.length,
        );
        try {
          await service.generateSection(source: source, selection: selection);
          done++;
        } on Object catch (e) {
          failures.add('${source.material.title}: ${_message(e)}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _progressValue = null;
        });
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $done of ${sources.length} section(s)'
          '${failures.isEmpty ? '.' : ' — ${failures.length} failed.'}',
        ),
      ),
    );
    if (failures.isNotEmpty) _showFailures(failures);
  }

  Future<void> _generateOverview() async {
    final count = await _askExampleCount('Examples & big picture');
    if (count == null || !mounted) return;
    final selection = await _pickModel('Generate examples & big picture with');
    if (selection == null || !mounted) return;
    final service = ref.read(courseReviewServiceProvider);
    setState(() => _busy = true);
    _setProgress('Writing $count examples and the big picture…', null);
    try {
      final state = await service.repository.load(widget.subjectId);
      if (state == null) return;
      await service.generateOverview(
        state: state,
        exampleCount: count,
        selection: selection,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Examples and big picture saved.')),
        );
      }
    } on Object catch (e) {
      if (mounted) _showFailures([_message(e)]);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  void _setProgress(String text, double? value) {
    if (!mounted) return;
    setState(() {
      _progress = text;
      _progressValue = value;
    });
  }

  Future<int?> _askExampleCount(String title) {
    var value = _exampleCount.toDouble();
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${value.round()} short examples for the whole course'),
              Slider(
                value: value,
                min: CourseReviewPrompts.minExampleCount.toDouble(),
                max: CourseReviewPrompts.maxExampleCount.toDouble(),
                divisions:
                    CourseReviewPrompts.maxExampleCount -
                    CourseReviewPrompts.minExampleCount,
                label: '${value.round()}',
                onChanged: (v) => setDialogState(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _exampleCount = value.round();
                Navigator.pop(context, _exampleCount);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(CourseReviewEntry entry, CourseReviewPart part) async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FullExplanationScreen(
          initialText: MarkdownToQuill.toDeltaJson(entry.content),
          title: 'Edit ${part.label.toLowerCase()}',
        ),
      ),
    );
    if (edited == null || !mounted) return;
    final markdown = QuillToMarkdown.fromStored(edited).trim();
    if (markdown.isEmpty || markdown == entry.content.trim()) return;
    await ref
        .read(courseReviewServiceProvider)
        .saveEdit(entry: entry, content: markdown);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved as v${entry.version + 1}.')),
    );
  }

  void _openImport() {
    Navigator.of(context).pushNamed(
      AppRoutes.manualEntry,
      arguments: (subjectId: widget.subjectId),
    );
  }

  Future<void> _copySectionsPrompt(CourseReviewState state) async {
    final markdown = await ref.read(manualEntryInstructionProvider.future);
    final text =
        '${courseReviewPromptFromInstruction(markdown)}\n\n'
        'Subject: "${state.subject.name}"\n'
        'Lectures in this subject (use these exact lesson and pdf names):\n'
        '${CourseReviewPrompts.lectureList(state)}';
    await _copy(
      text,
      'Prompt copied. Paste it into the AI with the lecture slides or '
      'materials you want to add.',
    );
  }

  Future<void> _copyOverviewRequest(CourseReviewState state) async {
    if (state.withSections.isEmpty) {
      _showFailures(['Add at least one lecture section first.']);
      return;
    }
    final count = await _askExampleCount('Copy examples request');
    if (count == null) return;
    await _copy(
      CourseReviewPrompts.externalOverviewRequest(state, exampleCount: count),
      'Request copied with all current sections. Paste the AI\'s JSON into '
      'Import JSON.',
    );
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFailures(List<String> failures) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Some requests failed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final f in failures) Text('• $f')],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String _message(Object error) => switch (error) {
    AiException(:final message) => message,
    StateError(:final message) => message,
    FormatException(:final message) => message,
    _ => '$error',
  };
}
