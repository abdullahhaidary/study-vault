import 'package:flutter/material.dart';

import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';

export '../../ai_assistant/presentation/widgets/ai_model_picker.dart'
    show showAiModelSelector, AiModelPickerButton;

/// Legacy name — prefer [showAiModelSelector].
@Deprecated('Use showAiModelSelector')
Future<String?> showGeminiModelSelector(
  BuildContext context, {
  required String selectedModelId,
}) async {
  final selected = AiExecutionSelection.fromModelId(selectedModelId);
  final next = await showAiModelSelector(context, selected: selected);
  return next?.requestedModelId;
}
