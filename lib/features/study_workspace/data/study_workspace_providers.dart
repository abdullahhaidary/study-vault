import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/study_workspace_models.dart';

final studyWorkspaceProvider =
    StateNotifierProvider<StudyWorkspaceController, StudyWorkspaceState>((ref) {
      return StudyWorkspaceController();
    });

class StudyWorkspaceController extends StateNotifier<StudyWorkspaceState> {
  StudyWorkspaceController() : super(const StudyWorkspaceState());

  void open([StudyWorkspaceTab tab = StudyWorkspaceTab.chat]) {
    if (tab == state.activeTab) {
      state = state.copyWith(visible: true, minimized: false);
      return;
    }
    _select(tab, makeVisible: true);
  }

  void select(StudyWorkspaceTab tab) => _select(tab, makeVisible: false);

  void _select(StudyWorkspaceTab tab, {required bool makeVisible}) {
    if (!_tabAvailable(tab) || tab == state.activeTab) {
      if (makeVisible) {
        state = state.copyWith(visible: true, minimized: false);
      }
      return;
    }
    state = state.copyWith(
      visible: makeVisible ? true : state.visible,
      minimized: makeVisible ? false : state.minimized,
      activeTab: tab,
      backStack: [...state.backStack, state.activeTab],
      forwardStack: const [],
    );
  }

  void attachSource(
    StudyWorkspaceSource source, {
    bool open = false,
    StudyWorkspaceTab tab = StudyWorkspaceTab.source,
  }) {
    final sourceChanged = state.source?.materialId != source.materialId;
    state = state.copyWith(
      source: source,
      visible: open ? true : state.visible,
      minimized: open ? false : state.minimized,
      activeTab: open ? tab : state.activeTab,
      backStack: sourceChanged ? const [] : state.backStack,
      forwardStack: sourceChanged ? const [] : state.forwardStack,
    );
  }

  void updatePdfPage(String materialId, int page) {
    final source = state.source;
    if (source is! PdfWorkspaceSource ||
        source.materialId != materialId ||
        source.currentPage == page) {
      return;
    }
    state = state.copyWith(source: source.copyWith(currentPage: page));
  }

  void minimize() {
    if (!state.visible) return;
    state = state.copyWith(minimized: true);
  }

  void restore() {
    state = state.copyWith(visible: true, minimized: false);
  }

  void close() {
    state = state.copyWith(visible: false, minimized: false);
  }

  void goBack() {
    if (!state.canGoBack) return;
    final target = state.backStack.last;
    state = state.copyWith(
      activeTab: target,
      backStack: state.backStack.sublist(0, state.backStack.length - 1),
      forwardStack: [state.activeTab, ...state.forwardStack],
    );
  }

  void goForward() {
    if (!state.canGoForward) return;
    final target = state.forwardStack.first;
    state = state.copyWith(
      activeTab: target,
      backStack: [...state.backStack, state.activeTab],
      forwardStack: state.forwardStack.sublist(1),
    );
  }

  void setPanelWidth(double width) {
    state = state.copyWith(panelWidth: width.clamp(420, 960));
  }

  bool _tabAvailable(StudyWorkspaceTab tab) {
    if (tab == StudyWorkspaceTab.chat) return true;
    if (tab == StudyWorkspaceTab.source) return state.source != null;
    return state.source is PdfWorkspaceSource;
  }
}
