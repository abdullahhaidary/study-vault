import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_execution_selection.dart';
import 'ai_assistant_controller.dart';
import 'widgets/ai_model_picker.dart';

/// Key/consent check, then the provider/model picker preset to the global
/// default. Returns null when the user backs out of setup.
Future<AiExecutionSelection?> pickAiModel(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) async {
  if (!await AiAssistantController.ensureReady(context, ref)) return null;
  if (!context.mounted) return null;
  final selection = await AiExecutionSelection.fromGlobal(
    ref.read(aiSettingsStoreProvider),
    action: AiStudyAction.customPrompt,
  );
  if (!context.mounted) return null;
  return await showAiModelSelector(
        context,
        selected: selection,
        action: AiStudyAction.customPrompt,
        title: title,
      ) ??
      selection;
}

/// Readable message for AI and validation failures.
String aiErrorMessage(Object error) => switch (error) {
  AiException(:final message) => message,
  StateError(:final message) => message,
  FormatException(:final message) => message,
  _ => '$error',
};
