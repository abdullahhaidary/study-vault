import 'ascii_diagram_repair.dart';
import 'bare_fence_repair.dart';
import 'code_fence_cleanup.dart';

/// Best-effort fixes for Markdown that outside models commonly break on import.
abstract final class StudyMarkdownRepair {
  static String repair(String source) {
    final pre = CodeFenceCleanup.preprocess(source);
    final withCodeFences = BareFenceRepair.repair(pre);
    final withDiagrams = AsciiDiagramRepair.repair(withCodeFences);
    return CodeFenceCleanup.densify(withDiagrams);
  }
}
