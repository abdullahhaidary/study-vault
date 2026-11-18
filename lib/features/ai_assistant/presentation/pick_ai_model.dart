import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_execution_selection.dart';
import 'ai_assistant_controller.dart';
import 'widgets/ai_model_picker.dart';

/// Choose a model first, then check its key and consent. Cancelling the picker
/// never sends through the default provider.
Future<AiExecutionSelection?> pickAiModel(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  AiExecutionSelection? initialSelection,
}) async {
  final selection =
      initialSelection ??
      await AiExecutionSelection.fromGlobal(
        ref.read(aiSettingsStoreProvider),
        action: AiStudyAction.customPrompt,
      );
  if (!context.mounted) return null;
  final picked = await showAiModelSelector(
    context,
    selected: selection,
    action: AiStudyAction.customPrompt,
    title: title,
  );
  if (picked == null || !context.mounted) return null;
  if (!await AiAssistantController.ensureReady(context, ref, selection: picked)) {
    return null;
  }
  return picked;
}

/// Readable message for AI and validation failures.
String aiErrorMessage(Object error) => switch (error) {
  AiException(:final message) => message,
  StateError(:final message) => message,
  FormatException(:final message) => message,
  _ => '$error',
};
