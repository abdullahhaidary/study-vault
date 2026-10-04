import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/selection_ai_host.dart';
import 'selection_ai_launcher.dart';
import 'selection_ai_toolbar.dart';

/// Builds the toolbar callbacks shared by every selection surface.
class SelectionAiActions {
  SelectionAiActions({
    required this.context,
    required this.ref,
    required this.host,
    required this.selectedText,
    required this.onCopy,
    required this.dismiss,
    this.anchor,
  });

  final BuildContext context;
  final WidgetRef ref;
  final SelectionAiHost host;
  final String selectedText;
  final VoidCallback onCopy;
  final VoidCallback dismiss;
  final Offset? anchor;

  Widget toolbar(TextSelectionToolbarAnchors anchors) {
    return SelectionAiToolbar(
      anchors: anchors,
      onCopy: () {
        onCopy();
        dismiss();
      },
      onAi: () {
        dismiss();
        SelectionAiLauncher.open(
          context,
          ref,
          host: host,
          selectedText: selectedText,
          anchor: anchor ?? anchors.primaryAnchor,
        );
      },
      onTranslate: () {
        dismiss();
        SelectionAiLauncher.translate(
          context,
          ref,
          host: host,
          selectedText: selectedText,
          anchor: anchor ?? anchors.primaryAnchor,
        );
      },
      onNote: () {
        dismiss();
        SelectionAiLauncher.saveNote(
          context,
          ref,
          host: host,
          markdown: selectedText,
          selectedText: selectedText,
        );
      },
      onFlashcard: () {
        dismiss();
        SelectionAiLauncher.makeFlashcard(
          context,
          host: host,
          selectedText: selectedText,
        );
      },
      onPin: host.canAddPin
          ? () {
              dismiss();
              host.onAddPin!(selectedText);
            }
          : null,
    );
  }
}

/// Drop-in replacement for [SelectionArea] that shows the Study Vault
/// selection toolbar (Copy · AI · Translate · Note · Flashcard).
///
/// Touch / right-click use Flutter's context-menu path. For mouse drag
/// selections (desktop), where Flutter shows nothing, a toolbar is placed at
/// the pointer-release position.
class SelectionAiArea extends ConsumerStatefulWidget {
  const SelectionAiArea({
    super.key,
    required this.host,
    required this.child,
    this.focusNode,
  });

  final SelectionAiHost host;
  final Widget child;
  final FocusNode? focusNode;

  @override
  ConsumerState<SelectionAiArea> createState() => _SelectionAiAreaState();
}

class _SelectionAiAreaState extends ConsumerState<SelectionAiArea> {
  final _areaKey = GlobalKey<SelectionAreaState>();
  String _selected = '';
  OverlayEntry? _mouseToolbar;
  bool _mouseDrag = false;

  @override
  void dispose() {
    _removeMouseToolbar();
    super.dispose();
  }

  void _removeMouseToolbar() {
    _mouseToolbar?.remove();
    _mouseToolbar = null;
  }

  void _copy() {
    // The region owns the selected content; this is the only public hook to
    // copy it from a custom toolbar button.
    // ignore: deprecated_member_use
    _areaKey.currentState?.selectableRegion.copySelection(
      SelectionChangedCause.toolbar,
    );
  }

  void _hideContextMenu() {
    _areaKey.currentState?.selectableRegion.hideToolbar();
  }

  SelectionAiActions _actions(VoidCallback dismiss, {Offset? anchor}) {
    return SelectionAiActions(
      context: context,
      ref: ref,
      host: widget.host,
      selectedText: _selected,
      onCopy: _copy,
      dismiss: dismiss,
      anchor: anchor,
    );
  }

  void _showMouseToolbar(Offset globalPosition) {
    _removeMouseToolbar();
    if (_selected.trim().isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final anchors = TextSelectionToolbarAnchors(
      primaryAnchor: globalPosition - const Offset(0, 12),
      secondaryAnchor: globalPosition + const Offset(0, 12),
    );
    _mouseToolbar = OverlayEntry(
      builder: (_) => _actions(
        _removeMouseToolbar,
        anchor: globalPosition,
      ).toolbar(anchors),
    );
    overlay.insert(_mouseToolbar!);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _mouseDrag = event.kind == PointerDeviceKind.mouse;
        _removeMouseToolbar();
      },
      onPointerUp: (event) {
        if (!_mouseDrag || event.kind != PointerDeviceKind.mouse) return;
        if (event.buttons != 0) return;
        // Let SelectableRegion commit the final selection first.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMouseToolbar(event.position);
        });
      },
      child: SelectionArea(
        key: _areaKey,
        focusNode: widget.focusNode,
        onSelectionChanged: (content) {
          _selected = content?.plainText ?? '';
          if (_selected.trim().isEmpty) _removeMouseToolbar();
        },
        contextMenuBuilder: (context, regionState) {
          if (_selected.trim().isEmpty) {
            return AdaptiveTextSelectionToolbar.selectableRegion(
              selectableRegionState: regionState,
            );
          }
          return _actions(
            _hideContextMenu,
          ).toolbar(regionState.contextMenuAnchors);
        },
        child: widget.child,
      ),
    );
  }
}

/// Adds the selection toolbar to a Quill editor.
///
/// Wrap the [QuillEditor] with [SelectionAiQuillScope] (so mouse selections
/// show the toolbar) and pass [SelectionAiQuillScope.contextMenuBuilder] to
/// [QuillEditorConfig.contextMenuBuilder].
class SelectionAiQuillScope extends ConsumerStatefulWidget {
  const SelectionAiQuillScope({
    super.key,
    required this.controller,
    required this.editorKey,
    required this.child,
  });

  final QuillController controller;
  final GlobalKey<EditorState> editorKey;
  final Widget child;

  /// Context-menu builder for [QuillEditorConfig.contextMenuBuilder].
  static QuillEditorContextMenuBuilder contextMenuBuilder({
    required WidgetRef ref,
    required QuillController controller,
    required SelectionAiHost Function() host,
  }) {
    return (context, rawEditorState) {
      final selected = controller.selection.isCollapsed
          ? ''
          : controller.getPlainText();
      if (selected.trim().isEmpty) {
        return QuillRawEditorConfig.defaultContextMenuBuilder(
          context,
          rawEditorState,
        );
      }
      return TextFieldTapRegion(
        child: SelectionAiActions(
          context: context,
          ref: ref,
          host: host(),
          selectedText: selected,
          onCopy: () =>
              rawEditorState.copySelection(SelectionChangedCause.toolbar),
          dismiss: rawEditorState.hideToolbar,
        ).toolbar(rawEditorState.contextMenuAnchors),
      );
    };
  }

  @override
  ConsumerState<SelectionAiQuillScope> createState() =>
      _SelectionAiQuillScopeState();
}

class _SelectionAiQuillScopeState extends ConsumerState<SelectionAiQuillScope> {
  bool _mouseDrag = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) =>
          _mouseDrag = event.kind == PointerDeviceKind.mouse,
      onPointerUp: (event) {
        if (!_mouseDrag || event.kind != PointerDeviceKind.mouse) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.controller.selection.isCollapsed) return;
          widget.editorKey.currentState?.showToolbar();
        });
      },
      child: widget.child,
    );
  }
}
