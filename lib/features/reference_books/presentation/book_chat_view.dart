import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../domain/book_ai_input.dart';
import 'book_ai_request_picker.dart';
import '../../../core/widgets/transient_snack_bar.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/export/download_document_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../data/book_providers.dart';
import 'book_markdown.dart';

/// "Ask the book": answers come only from retrieved pages and cite them.
class BookChatView extends ConsumerStatefulWidget {
  const BookChatView({
    super.key,
    required this.book,
    required this.onOpenPage,
    this.initialChapterId,
    this.compact = false,
  });

  final ReferenceBook book;
  final ValueChanged<int> onOpenPage;
  final String? initialChapterId;
  final bool compact;

  @override
  ConsumerState<BookChatView> createState() => _BookChatViewState();
}

class _BookChatViewState extends ConsumerState<BookChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  AiExecutionSelection? _selection;
  BookAiInputMode _inputMode = BookAiInputMode.extractedText;
  late String? _chapterId = widget.initialChapterId;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final selected =
          _selection ??
          await pickAiModel(context, ref, title: 'Ask the book with');
      if (selected == null || !mounted) return;
      if (!await AiAssistantController.ensureReady(
            context,
            ref,
            selection: selected,
          ) ||
          !mounted) {
        return;
      }
      setState(() => _selection = selected);
      final chapters =
          ref.read(bookChaptersProvider(widget.book.id)).valueOrNull ??
          const [];
      final chapter = chapters.where((c) => c.id == _chapterId).firstOrNull;
      _input.clear();
      await ref
          .read(bookAiServiceProvider)
          .ask(
            book: widget.book,
            question: question,
            selection: selected,
            chapter: chapter,
            inputMode: _inputMode,
          );
    } on Object catch (e) {
      if (mounted) {
        _input.text = question;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(TransientSnackBar(content: Text(aiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _modelLabel() {
    final selected = _selection;
    if (selected == null) return 'Choose AI model';
    final profile = ref
        .watch(aiEndpointProfilesProvider)
        .valueOrNull
        ?.where((p) => p.id == selected.endpointProfileId)
        .firstOrNull;
    return '${profile?.name ?? selected.provider.displayName} · ${selected.modelRef.bareModelId}';
  }

  Future<void> _chooseModel() async {
    final picked = await pickAiModel(
      context,
      ref,
      title: 'Ask the book with',
      initialSelection: _selection,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selection = picked;
      // Switching models returns to the universally supported text mode.
      _inputMode = BookAiInputMode.extractedText;
    });
  }

  Future<void> _chooseInput() async {
    if (_selection == null) await _chooseModel();
    if (_selection == null || !mounted) return;
    final chapters =
        ref.read(bookChaptersProvider(widget.book.id)).valueOrNull ?? const [];
    final chapter = chapters.where((c) => c.id == _chapterId).firstOrNull;
    final chosen = await chooseBookInputMode(
      context,
      ref,
      selection: _selection!,
      initial: _inputMode,
      pageCount: chapter == null
          ? widget.book.pageCount
          : chapter.endPage - chapter.startPage + 1,
      sourceDescription: chapter == null
          ? 'PDF mode attaches the entire book (${widget.book.pageCount} pages). Text mode searches for relevant pages.'
          : 'PDF mode attaches "${chapter.title}", pages ${chapter.startPage}–${chapter.endPage}. Text mode searches within that chapter.',
    );
    if (chosen != null && mounted) setState(() => _inputMode = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages =
        ref.watch(bookMessagesProvider(widget.book.id)).valueOrNull ?? const [];
    final chapters =
        ref.watch(bookChaptersProvider(widget.book.id)).valueOrNull ?? const [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _sending ? null : _chooseModel,
                    icon: const Icon(Icons.psychology_outlined),
                    label: Text(_modelLabel()),
                  ),
                  TextButton.icon(
                    onPressed: _sending ? null : _chooseInput,
                    icon: Icon(
                      _inputMode == BookAiInputMode.pdfAttachment
                          ? Icons.picture_as_pdf
                          : Icons.text_snippet_outlined,
                    ),
                    label: Text(
                      _inputMode == BookAiInputMode.pdfAttachment
                          ? 'PDF attachment'
                          : 'Extracted text',
                    ),
                  ),
                ],
              ),
              if (_inputMode == BookAiInputMode.pdfAttachment)
                Text(
                  _chapterId == null
                      ? 'Sending the entire book PDF (${widget.book.pageCount} pages).'
                      : 'Sending the selected chapter as a PDF.',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.xs,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: chapters.any((c) => c.id == _chapterId)
                      ? _chapterId
                      : null,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        _inputMode == BookAiInputMode.pdfAttachment
                            ? 'Attach the whole book PDF'
                            : 'Search the whole book',
                      ),
                    ),
                    for (final c in chapters.where((c) => c.level == 0))
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          'Only: ${c.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _sending
                      ? null
                      : (v) => setState(() => _chapterId = v),
                ),
              ),
              if (messages.isNotEmpty)
                IconButton(
                  tooltip: 'Clear conversation',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: _sending
                      ? null
                      : () => ref
                            .read(bookRepositoryProvider)
                            .clearMessages(widget.book.id),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Ask anything about "${widget.book.title}". The app finds '
                      'the most relevant pages and the answer cites them — tap '
                      'a page to open it.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) => i == messages.length
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Finding pages and answering…'),
                              ],
                            ),
                          )
                        : _bubble(theme, messages[i]),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_sending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask the book…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(ThemeData theme, ReferenceBookMessage message) {
    final user = message.role == 'user';
    final pages = message.sourcePages == null
        ? const <int>[]
        : [for (final p in jsonDecode(message.sourcePages!) as List) p as int];
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.compact ? 520 : 760),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: user
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            user
                ? Text(message.content)
                : BookMarkdown(
                    data: message.content,
                    onOpenPage: widget.onOpenPage,
                  ),
            if (!user)
              Align(
                alignment: Alignment.centerRight,
                child: DownloadDocumentButton(
                  tooltip: 'Download Markdown',
                  request: () async => DocumentTextRequest(
                    fileName: '${widget.book.title} answer',
                    text: message.content,
                  ),
                ),
              ),
            if (pages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Sources:', style: theme.textTheme.labelSmall),
                  for (final p in pages)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('p. $p'),
                      onPressed: () => widget.onOpenPage(p),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
