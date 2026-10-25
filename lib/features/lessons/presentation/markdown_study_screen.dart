import '../../../core/widgets/transient_snack_bar.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/built_in_data.dart';
import '../../../core/markdown/study_markdown.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/presentation/widgets/ai_discussions_section.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../pdf_ai_materials/presentation/pdf_ai_materials_panel.dart';
import '../data/materials_providers.dart';

/// Study view for markdown/text lesson attachments (PDF-like sources).
class MarkdownStudyScreen extends ConsumerStatefulWidget {
  const MarkdownStudyScreen({
    super.key,
    required this.resourceId,
    required this.title,
    required this.filePath,
  });

  final String resourceId;
  final String title;
  final String filePath;

  @override
  ConsumerState<MarkdownStudyScreen> createState() =>
      _MarkdownStudyScreenState();
}

class _MarkdownStudyScreenState extends ConsumerState<MarkdownStudyScreen> {
  late Future<String> _load;
  bool _editing = false;
  bool _saving = false;
  bool _showAiMaterials = false;
  double? _sidePanelWidth;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load = _readFile();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<String> _readFile() async {
    final file = File(widget.filePath);
    if (!await file.exists()) {
      throw StateError('File is missing on this device.');
    }
    return file.readAsString();
  }

  Future<void> _reload() async {
    setState(() {
      _load = _readFile();
      _editing = false;
    });
  }

  Future<void> _startEdit(String content) async {
    _editController.text = content;
    setState(() => _editing = true);
  }

  Future<void> _saveEdit() async {
    final material = await ref.read(
      materialByIdProvider(widget.resourceId).future,
    );
    if (material == null) return;
    setState(() => _saving = true);
    try {
      await updateMarkdownMaterialContent(
        ref,
        material: material,
        markdown: _editController.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _load = Future.value(_editController.text);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const TransientSnackBar(content: Text('Saved')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        TransientSnackBar(content: Text('Could not save: $error')),
      );
    }
  }

  Widget _aiPanel() => PdfAiMaterialsPanel(
    materialId: widget.resourceId,
    title: widget.title,
    filePath: widget.filePath,
    onClose: () => setState(() => _showAiMaterials = false),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppSpacing.wideBreakpoint;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'AI explanations',
            onPressed: () =>
                setState(() => _showAiMaterials = !_showAiMaterials),
            icon: Icon(
              _showAiMaterials
                  ? Icons.auto_stories
                  : Icons.auto_stories_outlined,
            ),
          ),
          FavoriteStarButton(
            entityType: FavoriteEntityType.material,
            entityId: widget.resourceId,
          ),
          if (!_editing)
            IconButton(
              tooltip: 'Edit text',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final content = await _load;
                if (!mounted) return;
                await _startEdit(content);
              },
            )
          else ...[
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saving ? null : _saveEdit,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final document = _document();
          if (!_showAiMaterials) return document;
          if (!wide) {
            return Stack(
              children: [
                document,
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: _aiPanel(),
                  ),
                ),
              ],
            );
          }
          const minSide = 280.0, minDocument = 320.0, handle = 6.0;
          final maxSide = (constraints.maxWidth - minDocument - handle).clamp(
            minSide,
            constraints.maxWidth,
          );
          final side = (_sidePanelWidth ?? 460.0).clamp(minSide, maxSide);
          return Row(
            children: [
              Expanded(child: document),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => setState(
                    () => _sidePanelWidth = (side - details.delta.dx).clamp(
                      minSide,
                      maxSide,
                    ),
                  ),
                  onDoubleTap: () => setState(
                    () => _sidePanelWidth = (constraints.maxWidth - handle) / 2,
                  ),
                  child: SizedBox(
                    width: handle,
                    child: VerticalDivider(
                      width: handle,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              SizedBox(width: side, child: _aiPanel()),
            ],
          );
        },
      ),
    );
  }

  Widget _document() {
    return FutureBuilder<String>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not open document: ${snapshot.error}'),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final content = snapshot.data ?? '';
        if (_editing) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _editController,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Markdown / text',
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          );
        }
        return ScrollEdgeArrows(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              StudyMarkdown(data: content),
              const SizedBox(height: AppSpacing.xl),
              AiDiscussionsSection(
                kind: AiContextKind.material,
                id: widget.resourceId,
              ),
            ],
          ),
        );
      },
    );
  }
}
