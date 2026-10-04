import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../ai_assistant/domain/annotation_ai_context.dart';
import '../../ai_assistant/domain/inline_ai_models.dart';
import '../../ai_assistant/presentation/inline_ai_panel.dart';
import '../../ai_assistant/services/annotation_ai_context_builder.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../flashcards/data/flashcards_providers.dart';
import '../../notes/data/notes_providers.dart';
import '../domain/selection_ai_host.dart';
import 'selection_flashcard_dialog.dart';

/// Opens the inline AI box for a text selection anywhere in the app.
///
/// Flow: ask what context to send → build [AnnotationAiContext] → show the
/// shared [InlineAiOverlay] in the root overlay, wired to the host's
/// replace / insert / append callbacks.
abstract final class SelectionAiLauncher {
  static OverlayEntry? _current;

  static bool get isOpen => _current != null;

  static void close() {
    _current?.remove();
    _current = null;
  }

  static Future<void> open(
    BuildContext context,
    WidgetRef ref, {
    required SelectionAiHost host,
    required String selectedText,
    Offset? anchor,
    AnnotationAiContext? baseContext,
    AiStudyAction? initialAction,
    AiLanguage? translateTarget,
    AiContextScope? scope,
  }) async {
    final selected = selectedText.trim();
    if (selected.isEmpty) return;

    final base =
        baseContext ??
        AnnotationAiContextBuilder.fromTextSelection(
          selectedText: selected,
          documentText: host.documentText,
          materialId: host.materialId,
          lessonId: host.lessonId,
          pageNumber: host.pageNumber,
          sourceTitle: host.title,
        );

    final aiContext = await resolveContext(
      context,
      host: host,
      base: base,
      scope: scope,
    );
    if (aiContext == null || !context.mounted) return;
    final scopes = scopesFor(host, base);

    close();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => InlineAiOverlay(
        mode: InlineAiSourceMode.selection,
        aiContext: aiContext,
        anchorGlobal: anchor,
        initialAction: initialAction,
        initialTranslateTarget: translateTarget,
        callbacks: InlineAiHostCallbacks(
          onDismiss: () {
            if (_current == entry) close();
          },
          onCreateNote: (markdown) => saveNote(
            context,
            ref,
            host: host,
            markdown: markdown,
            selectedText: selected,
          ),
          onFlashcardsCreate: (cards) async {
            for (final card in cards) {
              await createFlashcard(
                ref,
                lessonId: host.lessonId,
                front: card.front,
                back: MarkdownToQuill.toDeltaJson(card.back),
              );
            }
          },
          onReplaceSelection: host.onReplaceSelection == null
              ? null
              : (markdown) => host.onReplaceSelection!(selected, markdown),
          onInsertBelow: host.onInsertBelow == null
              ? null
              : (markdown) => host.onInsertBelow!(selected, markdown),
          onAppendToEnd: host.onAppendToEnd == null
              ? null
              : (markdown) => host.onAppendToEnd!(selected, markdown),
          onChangeContext: scopes.length < 2
              ? null
              : () {
                  if (!context.mounted) return;
                  open(
                    context,
                    ref,
                    host: host,
                    selectedText: selected,
                    anchor: anchor,
                    baseContext: baseContext,
                  );
                },
        ),
      ),
    );
    _current = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  /// Scopes offered for [host]; "nearby" is added when [base] already
  /// carries a surrounding window (PDF page text).
  static List<AiContextScope> scopesFor(
    SelectionAiHost host,
    AnnotationAiContext base,
  ) {
    return <AiContextScope>{
      ...host.availableScopes,
      if ((base.surroundingText ?? '').trim().isNotEmpty)
        AiContextScope.surrounding,
    }.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  /// Asks the user which context to send (unless [scope] is given), loads
  /// the summary / full text when needed and returns the final context.
  /// Returns `null` when the user cancels.
  static Future<AnnotationAiContext?> resolveContext(
    BuildContext context, {
    required SelectionAiHost host,
    required AnnotationAiContext base,
    AiContextScope? scope,
  }) async {
    final scopes = scopesFor(host, base);
    final chosen = scope ?? await _pickScope(context, host, scopes);
    if (chosen == null || !context.mounted) return null;

    String? summary;
    String? fullText;
    try {
      if (chosen == AiContextScope.summary) {
        summary = await host.loadSummary?.call();
      } else if (chosen == AiContextScope.fullText) {
        fullText = host.loadFullText != null
            ? await host.loadFullText!()
            : host.documentText;
      }
    } catch (_) {
      summary = null;
      fullText = null;
    }
    if (!context.mounted) return null;

    if ((chosen == AiContextScope.summary && (summary ?? '').trim().isEmpty) ||
        (chosen == AiContextScope.fullText &&
            (fullText ?? '').trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chosen == AiContextScope.summary
                ? 'No summary is saved for this document yet. Sending the selection only.'
                : 'Could not read the document text. Sending the selection only.',
          ),
        ),
      );
    }

    return AnnotationAiContextBuilder.withScope(
      base,
      scope: chosen,
      summaryText: summary,
      fullText: fullText,
    );
  }

  static Future<AiContextScope?> _pickScope(
    BuildContext context,
    SelectionAiHost host,
    List<AiContextScope> scopes,
  ) {
    if (scopes.length == 1) return Future.value(scopes.single);
    return showModalBottomSheet<AiContextScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('What should AI see?'),
              subtitle: Text('Besides your selection from ${host.title}'),
            ),
            for (final scope in scopes)
              ListTile(
                leading: Icon(_iconFor(scope)),
                title: Text(scope.label),
                subtitle: Text(scope.description),
                onTap: () => Navigator.pop(context, scope),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(AiContextScope scope) => switch (scope) {
    AiContextScope.selectionOnly => Icons.text_fields,
    AiContextScope.surrounding => Icons.wrap_text,
    AiContextScope.summary => Icons.summarize_outlined,
    AiContextScope.fullText => Icons.article_outlined,
  };

  /// Copies [text] and confirms with a snackbar.
  static Future<void> copy(BuildContext context, String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }

  /// Saves [markdown] (or the raw selection) as a lesson note.
  static Future<void> saveNote(
    BuildContext context,
    WidgetRef ref, {
    required SelectionAiHost host,
    required String markdown,
    required String selectedText,
  }) async {
    final raw = selectedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = raw.length > 48 ? '${raw.substring(0, 48)}…' : raw;
    await createStudyNote(
      ref,
      lessonId: host.lessonId,
      title: title.isEmpty ? 'Note from ${host.title}' : title,
      content: MarkdownToQuill.toDeltaJson(markdown),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            host.lessonId == null
                ? 'Note created (not linked to a lesson)'
                : 'Note created',
          ),
        ),
      );
    }
  }

  /// Opens the flashcard dialog with the selection as the front.
  static Future<void> makeFlashcard(
    BuildContext context, {
    required SelectionAiHost host,
    required String selectedText,
  }) async {
    final created = await SelectionFlashcardDialog.show(
      context,
      front: selectedText,
      lessonId: host.lessonId,
    );
    if (created && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Flashcard created')));
    }
  }

  /// Translate shortcut: picks the target language, then opens the box with
  /// the translation already running.
  static Future<void> translate(
    BuildContext context,
    WidgetRef ref, {
    required SelectionAiHost host,
    required String selectedText,
    Offset? anchor,
    AnnotationAiContext? baseContext,
  }) async {
    final target = await showModalBottomSheet<AiLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Translate to')),
            for (final lang in const [
              AiLanguage.english,
              AiLanguage.persianDari,
            ])
              ListTile(
                title: Text(lang.label),
                onTap: () => Navigator.pop(context, lang),
              ),
          ],
        ),
      ),
    );
    if (target == null || !context.mounted) return;
    await open(
      context,
      ref,
      host: host,
      selectedText: selectedText,
      anchor: anchor,
      baseContext: baseContext,
      initialAction: AiStudyAction.translate,
      translateTarget: target,
      scope: AiContextScope.selectionOnly,
    );
  }
}
