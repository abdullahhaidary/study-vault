import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/system_bottom_inset.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/ai_models.dart';
import '../domain/ai_token_usage.dart';
import '../services/markdown_to_quill.dart';
import 'widgets/ai_usage_indicator.dart';

Future<void> showAiFlashcardsPreview(
  BuildContext context, {
  required List<AiFlashcardDraft> cards,
  AiTokenUsage? usage,
  Future<void> Function(List<AiFlashcardDraft> cards)? onCreate,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AiFlashcardsPreviewScreen(
        initialCards: cards,
        usage: usage,
        onCreate: onCreate,
      ),
    ),
  );
}

class AiFlashcardsPreviewScreen extends StatefulWidget {
  const AiFlashcardsPreviewScreen({
    super.key,
    required this.initialCards,
    this.usage,
    this.onCreate,
  });

  final List<AiFlashcardDraft> initialCards;
  final AiTokenUsage? usage;
  final Future<void> Function(List<AiFlashcardDraft> cards)? onCreate;

  @override
  State<AiFlashcardsPreviewScreen> createState() =>
      _AiFlashcardsPreviewScreenState();
}

class _AiFlashcardsPreviewScreenState extends State<AiFlashcardsPreviewScreen> {
  late List<_EditableCard> _cards;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cards = [
      for (final c in widget.initialCards)
        _EditableCard(
          selected: true,
          front: TextEditingController(text: c.front),
          back: TextEditingController(text: c.back),
        ),
    ];
  }

  @override
  void dispose() {
    for (final c in _cards) {
      c.front.dispose();
      c.back.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcard drafts')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cards.length + (widget.usage?.hasAnyMetric == true ? 1 : 0),
        itemBuilder: (context, index) {
          if (widget.usage?.hasAnyMetric == true && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AiUsageIndicator(usage: widget.usage!),
            );
          }
          final cardIndex = widget.usage?.hasAnyMetric == true
              ? index - 1
              : index;
          final card = _cards[cardIndex];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: card.selected,
                    onChanged: (v) =>
                        setState(() => card.selected = v ?? false),
                    title: Text('Card ${cardIndex + 1}'),
                  ),
                  TextField(
                    controller: card.front,
                    decoration: const InputDecoration(
                      labelText: 'Front',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: card.back,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Back',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SystemBottomSafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton.icon(
                onPressed: _cards.isEmpty
                    ? null
                    : () async {
                        final text = [
                          for (var i = 0; i < _cards.length; i++)
                            'Q${i + 1}. ${_cards[i].front.text}\nA: '
                                '${StudyNoteCodec.isRichDeltaJson(_cards[i].back.text) ? StudyNoteCodec.decode(_cards[i].back.text).toPlainText().trimRight() : _cards[i].back.text}',
                        ].join('\n\n');
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final selected = _cards
                            .where((c) => c.selected)
                            .map(
                              (c) => AiFlashcardDraft(
                                front: c.front.text.trim(),
                                back: MarkdownToQuill.toDeltaJson(
                                  c.back.text.trim(),
                                ),
                              ),
                            )
                            .where(
                              (c) =>
                                  c.front.isNotEmpty &&
                                  c.back.trim().isNotEmpty,
                            )
                            .toList();
                        if (selected.isEmpty) return;
                        setState(() => _saving = true);
                        await widget.onCreate?.call(selected);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Create Selected Flashcards'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableCard {
  _EditableCard({
    required this.selected,
    required this.front,
    required this.back,
  });

  bool selected;
  final TextEditingController front;
  final TextEditingController back;
}
