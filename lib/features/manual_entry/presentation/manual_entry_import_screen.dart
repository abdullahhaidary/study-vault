import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../lessons/data/materials_providers.dart' show isPdfMimeType;
import '../data/manual_entry_providers.dart';
import '../domain/manual_entry_models.dart';
import '../domain/manual_entry_plan.dart';
import 'manual_entry_item_reader.dart';
import 'manual_entry_preview_screen.dart';

/// Paste AI-produced JSON → pick target → review → preview → save.
class ManualEntryImportScreen extends ConsumerStatefulWidget {
  const ManualEntryImportScreen({super.key, this.initialLessonId});

  /// When opened from a lesson, pre-selects that class/subject/lesson.
  final String? initialLessonId;

  @override
  ConsumerState<ManualEntryImportScreen> createState() =>
      _ManualEntryImportScreenState();
}

class _ManualEntryImportScreenState
    extends ConsumerState<ManualEntryImportScreen> {
  final _json = TextEditingController();

  ManualEntryBundle? _bundle;
  String? _parseError;
  bool _showWarnings = false;

  List<StudyClass> _classes = const [];
  List<Subject> _subjects = const [];
  List<Lesson> _lessons = const [];
  List<LessonMaterial> _pdfs = const [];
  String? _classId;
  String? _subjectId;
  String? _lessonId;
  String? _pdfId;
  final _matched = <String>{};

  ManualEntryPlan? _plan;
  bool _building = false;
  bool _saving = false;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  Future<void> _loadHierarchy() async {
    final classes = await _db.watchAllClasses().first;
    if (!mounted) return;
    setState(() => _classes = classes);
    final lessonId = widget.initialLessonId;
    if (lessonId == null) return;
    final lesson = await _db.getLessonById(lessonId);
    final subject = lesson == null
        ? null
        : await _db.getSubjectById(lesson.subjectId);
    if (lesson == null || subject == null || !mounted) return;
    await _selectClass(subject.classId);
    await _selectSubject(subject.id);
    await _selectLesson(lesson.id);
  }

  Future<void> _selectClass(String? id) async {
    final subjects = id == null
        ? const <Subject>[]
        : await _db.watchSubjectsForClass(id).first;
    if (!mounted) return;
    setState(() {
      _classId = id;
      _subjects = subjects;
      _subjectId = null;
      _lessons = const [];
      _lessonId = null;
      _pdfs = const [];
      _pdfId = null;
      _plan = null;
    });
  }

  Future<void> _selectSubject(String? id) async {
    final lessons = id == null
        ? const <Lesson>[]
        : await _db.watchLessonsForSubject(id).first;
    if (!mounted) return;
    setState(() {
      _subjectId = id;
      _lessons = lessons;
      _lessonId = null;
      _pdfs = const [];
      _pdfId = null;
      _plan = null;
    });
  }

  Future<void> _selectLesson(String? id) async {
    final materials = id == null
        ? const <LessonMaterial>[]
        : await _db.watchMaterialsForLesson(id).first;
    if (!mounted) return;
    setState(() {
      _lessonId = id;
      _pdfs = [
        for (final m in materials)
          if (isPdfMimeType(m.mimeType)) m,
      ];
      _pdfId = _pdfs.length == 1 ? _pdfs.first.id : null;
    });
    await _rebuildPlan();
  }

  void _selectPdf(String? id) {
    setState(() => _pdfId = id);
    _rebuildPlan();
  }

  Future<void> _parse() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _parseError = null;
      _bundle = null;
      _plan = null;
      _matched.clear();
    });
    try {
      final bundle = ManualEntryParser.parse(_json.text);
      if (bundle.isEmpty) {
        throw const ManualEntryFormatException(
          'The JSON parsed, but it contains nothing to import.',
        );
      }
      setState(() => _bundle = bundle);
      await _applyTargetHint(bundle.target);
      await _rebuildPlan();
    } on ManualEntryFormatException catch (e) {
      setState(() => _parseError = e.message);
    }
  }

  /// Pre-select whatever the JSON names, but only when it exists.
  Future<void> _applyTargetHint(ManualEntryTargetHint hint) async {
    bool same(String a, String? b) =>
        b != null && a.trim().toLowerCase() == b.trim().toLowerCase();

    if (_lessonId == null || hint.lessonName != null) {
      final cls = hint.className == null
          ? null
          : _classes.where((c) => same(c.name, hint.className)).firstOrNull;
      if (cls != null && cls.id != _classId) {
        await _selectClass(cls.id);
        _matched.add('class');
      }
      if (_classId != null) {
        final subject = _subjects
            .where((s) => same(s.name, hint.subjectName))
            .firstOrNull;
        if (subject != null && subject.id != _subjectId) {
          await _selectSubject(subject.id);
          _matched.add('subject');
        }
      } else if (hint.subjectName != null) {
        // No class hint: search every class for the subject name.
        for (final cls in _classes) {
          final subjects = await _db.watchSubjectsForClass(cls.id).first;
          final subject = subjects
              .where((s) => same(s.name, hint.subjectName))
              .firstOrNull;
          if (subject != null) {
            await _selectClass(cls.id);
            await _selectSubject(subject.id);
            _matched.addAll(['class', 'subject']);
            break;
          }
        }
      }
      if (_subjectId != null) {
        final lesson = _lessons
            .where((l) => same(l.name, hint.lessonName))
            .firstOrNull;
        if (lesson != null && lesson.id != _lessonId) {
          await _selectLesson(lesson.id);
          _matched.add('lesson');
        }
      }
    }
    if (_lessonId != null && hint.pdfTitle != null) {
      final pdf = _pdfs.where((p) => same(p.title, hint.pdfTitle)).firstOrNull;
      if (pdf != null) {
        _pdfId = pdf.id;
        _matched.add('pdf');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _rebuildPlan() async {
    final bundle = _bundle;
    final lessonId = _lessonId;
    if (bundle == null || lessonId == null) {
      setState(() => _plan = null);
      return;
    }
    setState(() => _building = true);
    final lesson = _lessons.firstWhere((l) => l.id == lessonId);
    final pdf = _pdfs.where((p) => p.id == _pdfId).firstOrNull;
    final plan = await ref
        .read(manualEntryImportServiceProvider)
        .buildPlan(
          bundle: bundle,
          target: ManualEntryTarget(
            lessonId: lesson.id,
            lessonName: lesson.name,
            subjectId: lesson.subjectId,
            materialId: pdf?.id,
            materialTitle: pdf?.title,
          ),
          previous: _plan,
        );
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _building = false;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Clipboard is empty.')));
      }
      return;
    }
    _json.text = text;
    await _parse();
  }

  Future<void> _copyInstructions({required bool full}) async {
    final markdown = await ref.read(manualEntryInstructionProvider.future);
    final text = full ? markdown : manualEntryPromptFromInstruction(markdown);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          full
              ? 'Full format guide copied.'
              : 'AI instruction copied. Paste it into ChatGPT with your slides.',
        ),
      ),
    );
  }

  Future<void> _openPreview() async {
    final plan = _plan;
    if (plan == null) return;
    final save = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ManualEntryPreviewScreen(plan: plan)),
    );
    if (!mounted) return;
    setState(() {});
    if (save == true) await _save();
  }

  Future<void> _save() async {
    final plan = _plan;
    if (plan == null || _saving) return;
    if (plan.missingPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a PDF, or untick the study materials / annotations.',
          ),
        ),
      );
      return;
    }
    if (plan.writeCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing is selected to save.')),
      );
      return;
    }
    final replacing = plan.items.where((i) => i.replaces).length;
    if (replacing > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Replace $replacing existing item(s)?'),
          content: const Text(
            'Replaced notes, flashcards, quizzes, and annotations are '
            'overwritten. Replaced AI materials lose their latest version. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace and save'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(manualEntryImportServiceProvider)
          .apply(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to ${plan.target.lessonName}: ${result.summary}',
          ),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.lessonDetails,
        (route) => route.isFirst,
        arguments: plan.target.lessonId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final canSave = plan != null && plan.writeCount > 0 && !plan.missingPdf;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Entry'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Instructions',
            onSelected: (v) => _copyInstructions(full: v == 'full'),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'prompt',
                child: Text('Copy AI instruction'),
              ),
              PopupMenuItem(
                value: 'full',
                child: Text('Copy full format guide'),
              ),
            ],
          ),
        ],
      ),
      body: ScrollEdgeArrows(
        child: ListView(
          padding: AppSpacing.pageInsets(context),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pasteCard(theme),
                    const SizedBox(height: AppSpacing.md),
                    if (_bundle != null) ...[
                      _targetCard(theme),
                      const SizedBox(height: AppSpacing.md),
                      if (_building)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (plan != null)
                        _reviewCard(theme, plan)
                      else
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.arrow_upward),
                            title: const Text(
                              'Choose a lesson to review items',
                            ),
                            subtitle: Text(
                              '${_bundle!.itemCount} item(s) ready to import.',
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: plan == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _openPreview,
                        icon: const Icon(Icons.preview_outlined),
                        label: const Text('Preview lesson'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canSave && !_saving ? _save : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text('Save ${plan.writeCount}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _pasteCard(ThemeData theme) {
    final bundle = _bundle;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('1 · Paste the JSON', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Give ChatGPT your slides plus the Study Vault instruction, '
              'then paste its JSON answer here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _json,
              minLines: 6,
              maxLines: 12,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: '{ "format": "study-vault-manual-entry", … }',
                border: const OutlineInputBorder(),
                errorText: _parseError,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste & parse'),
                ),
                OutlinedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.data_object),
                  label: const Text('Parse'),
                ),
                TextButton.icon(
                  onPressed: () => _copyInstructions(full: false),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy AI instruction'),
                ),
              ],
            ),
            if (bundle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final kind in ManualEntryKind.values)
                    if (_countInBundle(bundle, kind) > 0)
                      Chip(
                        avatar: Icon(_iconFor(kind), size: 16),
                        label: Text(
                          '${_countInBundle(bundle, kind)} ${kind.label}',
                        ),
                      ),
                ],
              ),
              if (bundle.warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () => setState(() => _showWarnings = !_showWarnings),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          '${bundle.warnings.length} item(s) skipped or adjusted',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                      Icon(
                        _showWarnings ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                if (_showWarnings)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in bundle.warnings)
                          Text('• $w', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _targetCard(ThemeData theme) {
    final bundle = _bundle!;
    final hint = bundle.target;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('2 · Where to save', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Names from the JSON are pre-selected when they already exist. '
              'Nothing is created automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _picker<StudyClass>(
              label: 'Class',
              hint: hint.className,
              matched: _matched.contains('class'),
              value: _classId,
              items: _classes,
              id: (c) => c.id,
              name: (c) => c.name,
              onChanged: _selectClass,
            ),
            const SizedBox(height: AppSpacing.sm),
            _picker<Subject>(
              label: 'Subject',
              hint: hint.subjectName,
              matched: _matched.contains('subject'),
              value: _subjectId,
              items: _subjects,
              id: (s) => s.id,
              name: (s) => s.name,
              onChanged: _classId == null ? null : _selectSubject,
            ),
            const SizedBox(height: AppSpacing.sm),
            _picker<Lesson>(
              label: 'Lesson',
              hint: hint.lessonName,
              matched: _matched.contains('lesson'),
              value: _lessonId,
              items: _lessons,
              id: (l) => l.id,
              name: (l) => l.name,
              onChanged: _subjectId == null ? null : _selectLesson,
            ),
            if (bundle.needsPdf) ...[
              const SizedBox(height: AppSpacing.sm),
              _picker<LessonMaterial>(
                label: 'PDF (for study materials & annotations)',
                hint: hint.pdfTitle,
                matched: _matched.contains('pdf'),
                value: _pdfId,
                items: _pdfs,
                id: (m) => m.id,
                name: (m) => m.title,
                onChanged: _lessonId == null ? null : _selectPdf,
              ),
              if (_lessonId != null && _pdfs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'This lesson has no PDF. Attach one first, or untick the '
                    'study materials and annotations below.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _picker<T>({
    required String label,
    required String? hint,
    required bool matched,
    required String? value,
    required List<T> items,
    required String Function(T) id,
    required String Function(T) name,
    required ValueChanged<String?>? onChanged,
  }) {
    final theme = Theme.of(context);
    final ids = items.map(id).toSet();
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${items.length}'),
      initialValue: ids.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: hint == null
            ? null
            : matched
            ? 'Matched "$hint" from JSON'
            : 'JSON said "$hint" — not found, choose manually',
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: matched
              ? theme.colorScheme.primary
              : theme.colorScheme.tertiary,
        ),
        helperMaxLines: 2,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: id(item),
            child: Text(name(item), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _reviewCard(ThemeData theme, ManualEntryPlan plan) {
    final conflicts = plan.items.where((i) => i.hasConflict).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '3 · Review items',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    final all = plan.items.every((i) => i.included);
                    for (final i in plan.items) {
                      i.included = !all;
                    }
                  }),
                  child: Text(
                    plan.items.every((i) => i.included)
                        ? 'Untick all'
                        : 'Tick all',
                  ),
                ),
              ],
            ),
            Text(
              conflicts == 0
                  ? 'Tap a title to read it. Everything ticked is saved.'
                  : '$conflicts item(s) overlap existing content — choose '
                        'Add, Replace, or Skip for each.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (plan.missingPdf)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Study materials and annotations need a PDF.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            for (final kind in ManualEntryKind.values)
              if (plan.ofKind(kind).isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      _iconFor(kind),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      kind.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${plan.before.forKind(kind)} → ${plan.after.forKind(kind)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                for (final item in plan.ofKind(kind)) _itemTile(theme, item),
              ],
          ],
        ),
      ),
    );
  }

  Widget _itemTile(ThemeData theme, ManualEntryPlanItem item) {
    final dim = !item.included || item.resolution == ConflictResolution.skip;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Material(
        color: item.hasConflict && !dim
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxs,
            AppSpacing.xxs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: item.included,
                    onChanged: (v) =>
                        setState(() => item.included = v ?? false),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => ManualEntryItemReader.open(context, item),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: dim
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: dim
                                    ? theme.colorScheme.onSurfaceVariant
                                    : null,
                              ),
                            ),
                            if (item.preview.isNotEmpty &&
                                item.preview != item.title)
                              Text(
                                item.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (item.detail != null)
                              Text(
                                item.detail!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Read',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => ManualEntryItemReader.open(context, item),
                  ),
                ],
              ),
              if (item.hasConflict && item.included) ...[
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    'Overlaps: ${item.existing!.description}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: SegmentedButton<ConflictResolution>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      for (final r in ConflictResolution.values)
                        ButtonSegment(
                          value: r,
                          label: Text(r.label(item.kind)),
                        ),
                    ],
                    selected: {item.resolution},
                    onSelectionChanged: (s) =>
                        setState(() => item.resolution = s.first),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static int _countInBundle(ManualEntryBundle b, ManualEntryKind kind) =>
      switch (kind) {
        ManualEntryKind.studyMaterial => b.studyMaterials.length,
        ManualEntryKind.note => b.notes.length,
        ManualEntryKind.annotation => b.annotations.length,
        ManualEntryKind.flashcard => b.flashcards.length,
        ManualEntryKind.quiz => b.quizzes.length,
      };
}

IconData manualEntryKindIcon(ManualEntryKind kind) => switch (kind) {
  ManualEntryKind.studyMaterial => Icons.library_books_outlined,
  ManualEntryKind.note => Icons.notes_outlined,
  ManualEntryKind.annotation => Icons.push_pin_outlined,
  ManualEntryKind.flashcard => Icons.style_outlined,
  ManualEntryKind.quiz => Icons.quiz_outlined,
};

IconData _iconFor(ManualEntryKind kind) => manualEntryKindIcon(kind);
