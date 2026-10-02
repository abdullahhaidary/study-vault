import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../search/data/search_providers.dart';
import '../../../search/domain/study_search_result.dart';
import '../../domain/ai_chat_models.dart';
import '../../services/chat_context_resolver.dart';

/// Opens the Study Vault mention picker as a modal bottom sheet.
Future<AiContextItem?> showChatMentionPicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<AiContextItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ChatMentionPickerSheet(initialQuery: initialQuery),
  );
}

class _ChatMentionPickerSheet extends ConsumerStatefulWidget {
  const _ChatMentionPickerSheet({this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<_ChatMentionPickerSheet> createState() =>
      _ChatMentionPickerSheetState();
}

class _ChatMentionPickerSheetState
    extends ConsumerState<_ChatMentionPickerSheet> {
  late final TextEditingController _query;
  List<StudySearchResult> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
    _query.addListener(_scheduleReload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _query.removeListener(_scheduleReload);
    _query.dispose();
    super.dispose();
  }

  void _scheduleReload() {
    // Debounce lightly by scheduling after frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    final q = _query.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(studySearchServiceProvider);
      final results = await service.searchForMentions(q);
      if (!mounted || _query.text != q) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not search study content.';
        _results = const [];
      });
      debugPrint('Mention search failed: $e');
    }
  }

  void _select(StudySearchResult hit) {
    final kind = AiContextKindX.fromSearchKind(hit.kind);
    if (kind == null) return;
    final item = ChatContextResolver(
      db: ref.read(databaseProvider),
    ).draftFromSearch(hit);
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final groups = <String, List<StudySearchResult>>{};
    for (final hit in _results) {
      final label = switch (hit.kind) {
        StudyEntityKind.lesson => 'Lessons',
        StudyEntityKind.material => 'Materials',
        StudyEntityKind.note => 'Notes',
        StudyEntityKind.studyPin => 'Pins',
        _ => 'Other',
      };
      groups.putIfAbsent(label, () => []).add(hit);
    }

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Attach study content', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Lessons, PDFs, notes, and pins. Text is extracted when you send.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _query,
                autofocus: widget.initialQuery.isNotEmpty,
                decoration: const InputDecoration(
                  hintText: 'Search lessons, slides, notes…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          _query.text.trim().isEmpty
                              ? 'No recent study content yet.'
                              : 'No matches.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                entry.key,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            for (final hit in entry.value)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(_iconFor(hit.kind)),
                                title: Text(hit.title),
                                subtitle: Text(
                                  hit.breadcrumb,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _select(hit),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(StudyEntityKind kind) => switch (kind) {
    StudyEntityKind.lesson => Icons.article_outlined,
    StudyEntityKind.material => Icons.picture_as_pdf_outlined,
    StudyEntityKind.note => Icons.sticky_note_2_outlined,
    StudyEntityKind.studyPin => Icons.push_pin_outlined,
    _ => Icons.attach_file,
  };
}
