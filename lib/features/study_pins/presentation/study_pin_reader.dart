import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../data/study_pins_providers.dart';
import '../domain/pin_type.dart';
import '../domain/study_note_codec.dart';
import 'widgets/study_rich_text_viewer.dart';

/// Opens a read-only Study Pin explanation UI.
///
/// Desktop (≥720): floating overlay managed by the caller via [StudyPinReaderOverlay].
/// Mobile: large modal bottom sheet.
Future<void> showStudyPinReader(BuildContext context, {required StudyPin pin}) {
  final isWide = MediaQuery.sizeOf(context).width >= 720;
  if (isWide) {
    // Desktop callers should prefer [StudyPinReaderOverlay] inside a Stack so
    // the PDF stays visible. This dialog is a fallback.
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Dialog(
        alignment: Alignment.centerRight,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: StudyPinReaderPanel(
            pin: pin,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => StudyPinReaderPanel(
        pin: pin,
        scrollController: controller,
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// Floating, draggable, resizable reader for desktop PDF/image study screens.
class StudyPinReaderOverlay extends StatefulWidget {
  const StudyPinReaderOverlay({
    super.key,
    required this.pin,
    required this.onClose,
    this.initialOffset = const Offset(24, 88),
    this.initialSize = const Size(360, 420),
  });

  final StudyPin pin;
  final VoidCallback onClose;
  final Offset initialOffset;
  final Size initialSize;

  @override
  State<StudyPinReaderOverlay> createState() => _StudyPinReaderOverlayState();
}

class _StudyPinReaderOverlayState extends State<StudyPinReaderOverlay> {
  late Offset _offset;
  late Size _size;
  bool _collapsed = false;

  static const _minSize = Size(280, 200);
  static const _collapsedHeight = 52.0;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
    _size = widget.initialSize;
  }

  @override
  void didUpdateWidget(covariant StudyPinReaderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin.id != widget.pin.id) {
      _collapsed = false;
    }
  }

  void _clampToParent(Size parentSize) {
    final height = _collapsed ? _collapsedHeight : _size.height;
    final maxW = parentSize.width.clamp(_minSize.width, double.infinity);
    final maxH = parentSize.height.clamp(_minSize.height, double.infinity);
    _size = Size(
      _size.width.clamp(_minSize.width, maxW),
      _size.height.clamp(_minSize.height, maxH),
    );
    _offset = Offset(
      _offset.dx.clamp(
        0.0,
        (parentSize.width - _size.width).clamp(0.0, double.infinity),
      ),
      _offset.dy.clamp(
        0.0,
        (parentSize.height - height).clamp(0.0, double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentSize = Size(constraints.maxWidth, constraints.maxHeight);
        _clampToParent(parentSize);
        final height = _collapsed ? _collapsedHeight : _size.height;

        return Stack(
          children: [
            Positioned(
              left: _offset.dx,
              top: _offset.dy,
              width: _size.width,
              height: height,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: Theme.of(context).colorScheme.surface,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _ReaderTitleBar(
                          title: widget.pin.shortText,
                          collapsed: _collapsed,
                          onDragDelta: (delta) {
                            setState(() {
                              _offset += delta;
                              _clampToParent(parentSize);
                            });
                          },
                          onToggleCollapse: () {
                            setState(() => _collapsed = !_collapsed);
                          },
                          onClose: widget.onClose,
                        ),
                        if (!_collapsed)
                          Expanded(
                            child: StudyPinReaderPanel(
                              pin: widget.pin,
                              onClose: widget.onClose,
                              showHeader: false,
                            ),
                          ),
                      ],
                    ),
                    if (!_collapsed)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _ResizeHandle(
                          onDragDelta: (delta) {
                            setState(() {
                              _size = Size(
                                (_size.width + delta.dx).clamp(
                                  _minSize.width,
                                  parentSize.width,
                                ),
                                (_size.height + delta.dy).clamp(
                                  _minSize.height,
                                  parentSize.height,
                                ),
                              );
                              _clampToParent(parentSize);
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReaderTitleBar extends StatelessWidget {
  const _ReaderTitleBar({
    required this.title,
    required this.collapsed,
    required this.onDragDelta,
    required this.onToggleCollapse,
    required this.onClose,
  });

  final String title;
  final bool collapsed;
  final ValueChanged<Offset> onDragDelta;
  final VoidCallback onToggleCollapse;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onDragDelta(details.delta),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: collapsed ? 'Expand' : 'Collapse',
              onPressed: onToggleCollapse,
              icon: Icon(
                collapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDragDelta});

  final ValueChanged<Offset> onDragDelta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDragDelta(details.delta),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: _ResizeAffordancePainter(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeAffordancePainter extends CustomPainter {
  _ResizeAffordancePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const inset = 6.0;
    for (var i = 0; i < 3; i++) {
      final o = inset + i * 4;
      canvas.drawLine(
        Offset(size.width - o, size.height - inset),
        Offset(size.width - inset, size.height - o),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResizeAffordancePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Read-only content for a Study Pin (short + full + selected source text).
class StudyPinReaderPanel extends StatelessWidget {
  const StudyPinReaderPanel({
    super.key,
    required this.pin,
    required this.onClose,
    this.scrollController,
    this.showHeader = true,
  });

  final StudyPin pin;
  final VoidCallback onClose;
  final ScrollController? scrollController;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFull = StudyNoteCodec.hasContent(pin.fullExplanation);
    final selected = pin.selectedText?.trim();
    final showSelected =
        pin.type == StudyPinType.text &&
        selected != null &&
        selected.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Study Annotation',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Text(
                'Short description',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(pin.shortText, style: theme.textTheme.titleMedium),
              if (showSelected) ...[
                const SizedBox(height: 16),
                Text(
                  'Selected text',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      selected,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Full Note',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              if (hasFull)
                StudyRichTextViewer(storedValue: pin.fullExplanation!)
              else
                Text(
                  'No full note yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
