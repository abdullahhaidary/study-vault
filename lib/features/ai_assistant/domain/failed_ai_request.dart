import 'ai_actions.dart';
import 'ai_models.dart';

/// A study AI request that failed and can be retried from the failure list.
class FailedAiRequest {
  FailedAiRequest({
    required this.id,
    required this.failedAt,
    required this.request,
    this.errorMessage,
    this.wasCancelled = false,
  });

  final String id;
  final DateTime failedAt;
  final AiStudyRequest request;
  final String? errorMessage;
  final bool wasCancelled;

  String get actionLabel => request.action.menuLabel;

  String get sourcePreview {
    final text = request.sourceText.trim();
    if (text.isEmpty) return 'No source text';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}
