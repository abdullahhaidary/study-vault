import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../../course_review/data/course_review_providers.dart';
import '../../course_review/domain/course_review_models.dart';
import '../data/book_providers.dart';
import '../domain/reading_plan.dart';
import 'book_actions.dart';
import 'book_indexer.dart';

/// Which book pages each lecture needs, and a reading plan to the exam.
class BookCourseView extends ConsumerStatefulWidget {
  const BookCourseView({super.key, required this.book});

  final ReferenceBook book;

  @override
  ConsumerState<BookCourseView> createState() => _BookCourseViewState();
}

class _BookCourseViewState extends ConsumerState<BookCourseView> {
  String? _subjectId;
  String? _progress;
  bool _stop = false;
  DateTime? _exam;
  double _pagesPerHour = 20;
  bool _includeOptional = false;

  String get _prefsKey => 'book_plan_${widget.book.id}_$_subjectId';

  Future<void> _loadPlanPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final exam = prefs.getString('${_prefsKey}_exam');
    if (!mounted) return;
    setState(() {
      _exam = exam == null ? null : DateTime.tryParse(exam);
      _pagesPerHour = prefs.getDouble('book_plan_pages_per_hour') ?? 20;
    });
  }

  Future<void> _savePlanPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_exam == null) {
      await prefs.remove('${_prefsKey}_exam');
    } else {
      await prefs.setString('${_prefsKey}_exam', _exam!.toIso8601String());
    }
    await prefs.setDouble('book_plan_pages_per_hour', _pagesPerHour);
  }

  Future<void> _match(List<CourseReviewSource> lectures) async {
    if (_progress != null || lectures.isEmpty) return;
    final selection = await pickAiModel(
      context,
      ref,
      title: lectures.length == 1
          ? 'Match lecture with'
          : 'Match ${lectures.length} lectures with',
    );
    if (selection == null || !mounted) return;
    final failures = <String>[];
    setState(() => _stop = false);
    for (var i = 0; i < lectures.length && !_stop; i++) {
      setState(
        () => _progress =
            'Matching ${i + 1} of ${lectures.length}: ${lectures[i].material.title}',
      );
      try {
        await ref
            .read(bookAiServiceProvider)
            .mapLecture(
              book: widget.book,
              lecture: lectures[i],
              selection: selection,
            );
      } on Object catch (e) {
        failures.add('${lectures[i].material.title}: ${aiErrorMessage(e)}');
      }
    }
    if (!mounted) return;
    setState(() => _progress = null);
    if (failures.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some lectures failed'),
          content: Text(failures.join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _editLink(ReferenceBookLink link) async {
    final start = TextEditingController(text: '${link.startPage}');
    final end = TextEditingController(text: '${link.endPage}');
    var priority = BookLinkPriority.fromStorage(link.priority);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Edit page range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: start,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'From'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: end,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'To'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<BookLinkPriority>(
                segments: [
                  for (final p in BookLinkPriority.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {priority},
                onSelectionChanged: (s) => setDialog(() => priority = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Remove'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final repository = ref.read(bookRepositoryProvider);
    final s = int.tryParse(start.text.trim());
    final e = int.tryParse(end.text.trim());
    start.dispose();
    end.dispose();
    if (result == 'delete') {
      await repository.deleteLink(link.id);
    } else if (result == 'save' &&
        s != null &&
        e != null &&
        s >= 1 &&
        e >= s &&
        e <= widget.book.pageCount) {
      await repository.updateLink(link, start: s, end: e, priority: priority);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.book;
    final subjects =
        ref.watch(bookSubjectsProvider(book.id)).valueOrNull ?? const [];
    if (subjects.isEmpty) {
      return EmptyState(
        icon: Icons.class_outlined,
        title: 'Link this book to a subject',
        message:
            'Then the app can find which pages each lecture needs and plan '
            'your reading until the exam.',
        action: FilledButton(
          onPressed: () => editBookDetails(context, ref, book),
          child: const Text('Link subjects'),
        ),
      );
    }
    if (!subjects.any((s) => s.id == _subjectId)) {
      _subjectId = subjects.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlanPrefs());
    }
    final review = ref.watch(courseReviewProvider(_subjectId!)).valueOrNull;
    final links = ref.watch(bookLinksProvider(book.id)).valueOrNull ?? const [];
    final lectures = review?.included.toList() ?? const <CourseReviewSource>[];
    final byMaterial = <String, List<ReferenceBookLink>>{};
    for (final l in links) {
      byMaterial.putIfAbsent(l.materialId, () => []).add(l);
    }
    final unmatched = [
      for (final l in lectures)
        if (!byMaterial.containsKey(l.material.id)) l,
    ];
    final indexing = ref.watch(bookIndexerProvider)[book.id]?.running ?? false;
    final ranges = [
      for (final lecture in lectures)
        for (final link
            in byMaterial[lecture.material.id] ?? const <ReferenceBookLink>[])
          PlanRange(
            id: link.id,
            lectureTitle: lecture.material.title,
            startPage: link.startPage,
            endPage: link.endPage,
            priority: BookLinkPriority.fromStorage(link.priority),
            done: link.done,
          ),
    ];
    final plan = _exam == null
        ? null
        : buildReadingPlan(
            ranges: ranges,
            today: DateTime.now(),
            examDate: _exam!,
            includeOptional: _includeOptional,
          );
    final linkById = {for (final l in links) l.id: l};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        96,
      ),
      children: [
        if (subjects.length > 1)
          DropdownButton<String>(
            value: _subjectId,
            isExpanded: true,
            items: [
              for (final s in subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) {
              setState(() => _subjectId = v);
              _loadPlanPrefs();
            },
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Read only what your course needs',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Each lecture is matched to book page ranges (one AI request '
                  'per lecture), marked Must read, Skim or Optional.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_progress != null) ...[
                  const LinearProgressIndicator(),
                  Row(
                    children: [
                      Expanded(child: Text(_progress!)),
                      TextButton(
                        onPressed: _stop
                            ? null
                            : () => setState(() => _stop = true),
                        child: Text(_stop ? 'Stopping…' : 'Stop after this'),
                      ),
                    ],
                  ),
                ] else
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      FilledButton.icon(
                        onPressed: indexing || unmatched.isEmpty
                            ? null
                            : () => _match(unmatched),
                        icon: const Icon(Icons.auto_awesome),
                        label: Text('Match lectures (${unmatched.length})'),
                      ),
                      OutlinedButton.icon(
                        onPressed: indexing || lectures.isEmpty
                            ? null
                            : () => _match(lectures),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-match all'),
                      ),
                    ],
                  ),
                if (indexing)
                  Text(
                    'Waiting for indexing to finish…',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        for (final lecture in lectures)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lecture.label,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Match again',
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _progress != null || indexing
                            ? null
                            : () => _match([lecture]),
                      ),
                    ],
                  ),
                  if (!byMaterial.containsKey(lecture.material.id))
                    Text('Not matched yet', style: theme.textTheme.bodySmall)
                  else if (byMaterial[lecture.material.id]!.isEmpty)
                    const Text('The book does not cover this lecture.')
                  else
                    for (final link in byMaterial[lecture.material.id]!)
                      _linkTile(link),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reading plan', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        _exam == null
                            ? 'Set exam date'
                            : 'Exam: ${DateFormat.yMMMd().format(_exam!)}',
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 730)),
                          initialDate:
                              _exam ?? now.add(const Duration(days: 30)),
                        );
                        if (picked == null) return;
                        setState(() => _exam = picked);
                        await _savePlanPrefs();
                      },
                    ),
                    FilterChip(
                      label: const Text('Include optional'),
                      selected: _includeOptional,
                      onSelected: (v) => setState(() => _includeOptional = v),
                    ),
                    SizedBox(
                      width: 220,
                      child: Row(
                        children: [
                          Text('${_pagesPerHour.round()} pages/hour'),
                          Expanded(
                            child: Slider(
                              value: _pagesPerHour,
                              min: 5,
                              max: 60,
                              divisions: 11,
                              onChanged: (v) =>
                                  setState(() => _pagesPerHour = v),
                              onChangeEnd: (_) => _savePlanPrefs(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (ranges.isEmpty)
                  const Text('Match lectures first to build a plan.')
                else if (plan == null)
                  Text(
                    '${ranges.where((r) => r.priority == BookLinkPriority.must).fold(0, (s, r) => s + r.pages)} '
                    'must-read pages. Set the exam date to spread them over '
                    'the days left.',
                  )
                else ...[
                  Text(
                    '${plan.mustPages} must-read + ${plan.skimPages} skim pages '
                    '(of ${book.pageCount}) · about '
                    '${plan.hours(_pagesPerHour).toStringAsFixed(1)} h left · '
                    '${(plan.effortPerDay / _pagesPerHour * 60).round()} min/day',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final day in plan.days)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(DateFormat.MMMEd().format(day.date)),
                      subtitle: Text(
                        '${day.ranges.length} range(s) · about '
                        '${(day.effort / _pagesPerHour * 60).round()} min',
                      ),
                      children: [
                        for (final r in day.ranges)
                          if (linkById[r.id] != null)
                            _linkTile(linkById[r.id]!, r.lectureTitle),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _linkTile(ReferenceBookLink link, [String? lecture]) {
    final priority = BookLinkPriority.fromStorage(link.priority);
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: link.done,
        onChanged: (v) =>
            ref.read(bookRepositoryProvider).setLinkDone(link, v ?? false),
      ),
      title: Text(
        'pp. ${link.startPage}–${link.endPage} · ${priority.label}',
        style: TextStyle(
          decoration: link.done ? TextDecoration.lineThrough : null,
          color: priority == BookLinkPriority.must
              ? theme.colorScheme.primary
              : null,
        ),
      ),
      subtitle: Text(
        [?lecture, ?link.reason].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openBookReader(context, widget.book, page: link.startPage),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _editLink(link),
      ),
    );
  }
}
