import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/deepseek_model_registry.dart';
import 'package:study_vault/features/ai_assistant/domain/gemini_model_registry.dart';

AiExecutionSelection testGeminiSelection({
  AiStudyAction? action,
  String? modelId,
}) {
  return AiExecutionSelection.resolve(
    provider: AiProviderId.gemini,
    requestedModelId: modelId ?? GeminiModelRegistry.defaultModelId,
    action: action,
  );
}

AiExecutionSelection testDeepSeekSelection({
  AiStudyAction? action,
  String? modelId,
}) {
  return AiExecutionSelection.resolve(
    provider: AiProviderId.deepseek,
    requestedModelId: modelId ?? DeepSeekModelRegistry.defaultModelId,
    action: action,
  );
}

AiExecutionSelection testDeepSeekAutoSelection({AiStudyAction? action}) {
  return AiExecutionSelection.resolve(
    provider: AiProviderId.deepseek,
    requestedModelId: DeepSeekModelIds.auto,
    action: action,
  );
}
