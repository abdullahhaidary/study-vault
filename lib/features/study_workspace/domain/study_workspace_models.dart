import 'package:flutter/foundation.dart';

enum StudyWorkspaceTab { chat, source, summary, explanation, deepExplanation }

extension StudyWorkspaceTabX on StudyWorkspaceTab {
  String get label => switch (this) {
    StudyWorkspaceTab.chat => 'Chat',
    StudyWorkspaceTab.source => 'Source',
    StudyWorkspaceTab.summary => 'Summary',
    StudyWorkspaceTab.explanation => 'Explain',
    StudyWorkspaceTab.deepExplanation => 'Deep',
  };
}

@immutable
sealed class StudyWorkspaceSource {
  const StudyWorkspaceSource({
    required this.materialId,
    required this.title,
    required this.filePath,
  });

  final String materialId;
  final String title;
  final String filePath;
}

@immutable
final class PdfWorkspaceSource extends StudyWorkspaceSource {
  const PdfWorkspaceSource({
    required super.materialId,
    required super.title,
    required super.filePath,
    this.currentPage,
  });

  final int? currentPage;

  PdfWorkspaceSource copyWith({int? currentPage}) {
    return PdfWorkspaceSource(
      materialId: materialId,
      title: title,
      filePath: filePath,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

@immutable
final class ImageWorkspaceSource extends StudyWorkspaceSource {
  const ImageWorkspaceSource({
    required super.materialId,
    required super.title,
    required super.filePath,
  });
}

@immutable
class StudyWorkspaceState {
  const StudyWorkspaceState({
    this.visible = false,
    this.minimized = false,
    this.activeTab = StudyWorkspaceTab.chat,
    this.source,
    this.backStack = const [],
    this.forwardStack = const [],
    this.panelWidth = 680,
  });

  final bool visible;
  final bool minimized;
  final StudyWorkspaceTab activeTab;
  final StudyWorkspaceSource? source;
  final List<StudyWorkspaceTab> backStack;
  final List<StudyWorkspaceTab> forwardStack;
  final double panelWidth;

  bool get canGoBack => backStack.isNotEmpty;
  bool get canGoForward => forwardStack.isNotEmpty;

  StudyWorkspaceState copyWith({
    bool? visible,
    bool? minimized,
    StudyWorkspaceTab? activeTab,
    StudyWorkspaceSource? source,
    bool clearSource = false,
    List<StudyWorkspaceTab>? backStack,
    List<StudyWorkspaceTab>? forwardStack,
    double? panelWidth,
  }) {
    return StudyWorkspaceState(
      visible: visible ?? this.visible,
      minimized: minimized ?? this.minimized,
      activeTab: activeTab ?? this.activeTab,
      source: clearSource ? null : source ?? this.source,
      backStack: backStack ?? this.backStack,
      forwardStack: forwardStack ?? this.forwardStack,
      panelWidth: panelWidth ?? this.panelWidth,
    );
  }
}
