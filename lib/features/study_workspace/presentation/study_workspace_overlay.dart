import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../app/routes.dart' as app_routes;
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/presentation/ai_chat_screen.dart';
import '../../ai_chat/services/ai_chat_navigation.dart';
import '../../pdf_ai_materials/data/pdf_ai_material_providers.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../data/study_workspace_providers.dart';
import '../domain/study_workspace_models.dart';

class StudyWorkspaceHost extends ConsumerWidget {
  const StudyWorkspaceHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyWorkspaceProvider);
    final controller = ref.read(studyWorkspaceProvider.notifier);

    return Stack(
      children: [
        Positioned.fill(child: child),
        if (state.visible)
          Positioned.fill(
            child: Offstage(
              offstage: state.minimized,
              child: _WorkspacePlacement(state: state),
            ),
          ),
        if (!state.visible || state.minimized)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: FloatingActionButton.extended(
                heroTag: 'global-study-workspace',
                onPressed: controller.restore,
                icon: const Icon(Icons.auto_awesome),
                label: Text(state.minimized ? 'Resume study' : 'Study AI'),
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkspacePlacement extends ConsumerWidget {
  const _WorkspacePlacement({required this.state});

  final StudyWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        final width = mobile
            ? constraints.maxWidth
            : state.panelWidth
                  .clamp(
                    420,
                    (constraints.maxWidth - AppSpacing.xl).clamp(420, 960),
                  )
                  .toDouble();

        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: mobile
                ? EdgeInsets.zero
                : const EdgeInsets.all(AppSpacing.sm),
            child: SizedBox(
              width: width,
              height: mobile ? constraints.maxHeight : double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(child: _StudyWorkspacePanel(state: state)),
                  if (!mobile)
                    Positioned(
                      left: 0,
                      top: 64,
                      bottom: 0,
                      width: 12,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            ref
                                .read(studyWorkspaceProvider.notifier)
                                .setPanelWidth(
                                  state.panelWidth - details.delta.dx,
                                );
                          },
                          child: const Center(child: VerticalDivider(width: 1)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StudyWorkspacePanel extends ConsumerWidget {
  const _StudyWorkspacePanel({required this.state});

  final StudyWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studyWorkspaceProvider.notifier);
    final theme = Theme.of(context);
    final source = state.source;

    return Material(
      elevation: 18,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: MediaQuery.sizeOf(context).width < 720
            ? BorderRadius.zero
            : AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous view',
                          onPressed: state.canGoBack ? controller.goBack : null,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        IconButton(
                          tooltip: 'Next view',
                          onPressed: state.canGoForward
                              ? controller.goForward
                              : null,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            source?.title ?? 'Study workspace',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (source != null)
                          IconButton(
                            tooltip:
                                source is PdfWorkspaceSource &&
                                    source.currentPage != null
                                ? 'Ask about page ${source.currentPage}'
                                : 'Ask about this material',
                            onPressed: () {
                              AiChatNavigation.openNewWithAttachment(
                                context,
                                ref,
                                attachment: AiContextItem(
                                  kind: AiContextKind.material,
                                  id: source.materialId,
                                  materialId: source.materialId,
                                  title: source.title,
                                  pageNumbers:
                                      source is PdfWorkspaceSource &&
                                          source.currentPage != null
                                      ? [source.currentPage!]
                                      : const [],
                                ),
                                draftText:
                                    source is PdfWorkspaceSource &&
                                        source.currentPage != null
                                    ? 'I have a question about page ${source.currentPage}.'
                                    : 'I have a question about this material.',
                              );
                            },
                            icon: const Icon(Icons.add_comment_outlined),
                          ),
                        IconButton(
                          tooltip: 'Minimize',
                          onPressed: controller.minimize,
                          icon: const Icon(Icons.minimize),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: controller.close,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      children: [
                        for (final tab in StudyWorkspaceTab.values)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xxs,
                            ),
                            child: FilterChip(
                              selected: state.activeTab == tab,
                              showCheckmark: false,
                              avatar: Icon(_tabIcon(tab), size: 17),
                              label: Text(tab.label),
                              onSelected: _enabled(tab, source)
                                  ? (_) => controller.select(tab)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Navigator(
              onGenerateRoute: (settings) {
                if (settings.name == Navigator.defaultRouteName) {
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const _WorkspaceBody(),
                  );
                }
                return app_routes.onGenerateRoute(settings);
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _enabled(StudyWorkspaceTab tab, StudyWorkspaceSource? source) {
    if (tab == StudyWorkspaceTab.chat) return true;
    if (tab == StudyWorkspaceTab.source) return source != null;
    return source is PdfWorkspaceSource;
  }

  IconData _tabIcon(StudyWorkspaceTab tab) => switch (tab) {
    StudyWorkspaceTab.chat => Icons.chat_bubble_outline,
    StudyWorkspaceTab.source => Icons.picture_as_pdf_outlined,
    StudyWorkspaceTab.summary => Icons.summarize_outlined,
    StudyWorkspaceTab.explanation => Icons.school_outlined,
    StudyWorkspaceTab.deepExplanation => Icons.psychology_outlined,
  };
}

class _WorkspaceBody extends ConsumerWidget {
  const _WorkspaceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyWorkspaceProvider);
    final controller = ref.read(studyWorkspaceProvider.notifier);
    final source = state.source;

    return IndexedStack(
      index: state.activeTab.index,
      children: [
        AiChatScreen(embedded: true, onClose: controller.minimize),
        _SourceView(source: source),
        _AiMaterialView(source: source, type: PdfAiMaterialType.summary),
        _AiMaterialView(source: source, type: PdfAiMaterialType.explanation),
        _AiMaterialView(
          source: source,
          type: PdfAiMaterialType.deepExplanation,
        ),
      ],
    );
  }
}

class _SourceView extends StatelessWidget {
  const _SourceView({required this.source});

  final StudyWorkspaceSource? source;

  @override
  Widget build(BuildContext context) {
    final current = source;
    if (current == null) {
      return const _WorkspaceEmpty(
        icon: Icons.description_outlined,
        message: 'Open a PDF or image to keep it available here.',
      );
    }
    return switch (current) {
      PdfWorkspaceSource() => _WorkspacePdfView(
        key: ValueKey(current.materialId),
        source: current,
      ),
      ImageWorkspaceSource() => _WorkspaceImageView(
        key: ValueKey(current.materialId),
        source: current,
      ),
    };
  }
}

class _WorkspacePdfView extends ConsumerStatefulWidget {
  const _WorkspacePdfView({super.key, required this.source});

  final PdfWorkspaceSource source;

  @override
  ConsumerState<_WorkspacePdfView> createState() => _WorkspacePdfViewState();
}

class _WorkspacePdfViewState extends ConsumerState<_WorkspacePdfView> {
  final _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    if (!File(widget.source.filePath).existsSync()) {
      return const _WorkspaceEmpty(
        icon: Icons.file_present_outlined,
        message: 'The source PDF is missing from local storage.',
      );
    }
    return PdfViewer.file(
      widget.source.filePath,
      controller: _controller,
      params: PdfViewerParams(
        margin: 8,
        onPageChanged: (page) {
          if (page == null) return;
          ref
              .read(studyWorkspaceProvider.notifier)
              .updatePdfPage(widget.source.materialId, page);
        },
        onViewerReady: (document, controller) {
          final page = widget.source.currentPage;
          if (page != null && page >= 1 && page <= document.pages.length) {
            controller.goToPage(pageNumber: page);
          }
        },
      ),
    );
  }
}

class _WorkspaceImageView extends StatelessWidget {
  const _WorkspaceImageView({super.key, required this.source});

  final ImageWorkspaceSource source;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.2,
      maxScale: 8,
      child: Center(
        child: Image.file(
          File(source.filePath),
          errorBuilder: (_, _, _) => const _WorkspaceEmpty(
            icon: Icons.broken_image_outlined,
            message: 'The source image could not be opened.',
          ),
        ),
      ),
    );
  }
}

class _AiMaterialView extends ConsumerStatefulWidget {
  const _AiMaterialView({required this.source, required this.type});

  final StudyWorkspaceSource? source;
  final PdfAiMaterialType type;

  @override
  ConsumerState<_AiMaterialView> createState() => _AiMaterialViewState();
}

class _AiMaterialViewState extends ConsumerState<_AiMaterialView> {
  final _scrollController = ScrollController();
  bool _generating = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generate(PdfWorkspaceSource source) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final selection = await AiExecutionSelection.fromGlobal(
        ref.read(aiSettingsStoreProvider),
        action: widget.type == PdfAiMaterialType.summary
            ? AiStudyAction.summarize
            : AiStudyAction.explain,
      );
      await ref
          .read(pdfAiMaterialServiceProvider)
          .generate(
            materialId: source.materialId,
            title: source.title,
            filePath: source.filePath,
            type: widget.type,
            selection: selection,
            customInstruction: '',
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate ${widget.type.shortName}.')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    if (source is! PdfWorkspaceSource) {
      return const _WorkspaceEmpty(
        icon: Icons.auto_awesome_outlined,
        message: 'Open a PDF to use AI study materials.',
      );
    }

    final materialsAsync = ref.watch(pdfAiMaterialsProvider(source.materialId));
    return materialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _WorkspaceEmpty(
        icon: Icons.error_outline,
        message: 'Could not load AI study materials.',
      ),
      data: (materials) {
        final selected = _latest(materials, widget.type);
        if (selected == null) {
          return _WorkspaceEmpty(
            icon: _materialIcon(widget.type),
            message: '${widget.type.shortName} has not been generated yet.',
            action: FilledButton.icon(
              onPressed: _generating ? null : () => _generate(source),
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Generating…' : 'Generate'),
            ),
          );
        }
        return Markdown(
          controller: _scrollController,
          data: selected.content,
          selectable: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
        );
      },
    );
  }

  PdfAiMaterial? _latest(
    List<PdfAiMaterial> materials,
    PdfAiMaterialType type,
  ) {
    for (final material in materials) {
      if (material.type == type.storageValue) return material;
    }
    return null;
  }

  IconData _materialIcon(PdfAiMaterialType type) => switch (type) {
    PdfAiMaterialType.summary => Icons.summarize_outlined,
    PdfAiMaterialType.explanation => Icons.school_outlined,
    PdfAiMaterialType.deepExplanation => Icons.psychology_outlined,
  };
}

class _WorkspaceEmpty extends StatelessWidget {
  const _WorkspaceEmpty({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
