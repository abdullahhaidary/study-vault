import 'package:flutter/foundation.dart';

@immutable
class StudyWorkspaceState {
  const StudyWorkspaceState({this.visible = false, this.minimized = false});

  final bool visible;
  final bool minimized;

  StudyWorkspaceState copyWith({bool? visible, bool? minimized}) {
    return StudyWorkspaceState(
      visible: visible ?? this.visible,
      minimized: minimized ?? this.minimized,
    );
  }
}
