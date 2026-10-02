import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/study_workspace_models.dart';

final studyWorkspaceProvider =
    StateNotifierProvider<StudyWorkspaceController, StudyWorkspaceState>((ref) {
      return StudyWorkspaceController();
    });

class StudyWorkspaceController extends StateNotifier<StudyWorkspaceState> {
  StudyWorkspaceController() : super(const StudyWorkspaceState());

  void open() => state = state.copyWith(visible: true, minimized: false);

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
}
