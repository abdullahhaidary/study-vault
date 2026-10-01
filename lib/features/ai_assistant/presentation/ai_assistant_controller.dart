import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_providers.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import '../services/markdown_to_quill.dart';
import 'ai_missing_key_dialog.dart';
import 'ai_privacy_dialog.dart';

/// Shared entry point for user-initiated AI actions.
abstract final class AiAssistantController {
  /// Ensures key + privacy consent. Returns false if user cancelled.
  static Future<bool> ensureReady(BuildContext context, WidgetRef ref) async {
    final service = ref.read(aiServiceProvider);
    if (!await service.isConfigured) {
      if (!context.mounted) return false;
      await showAiMissingKeyDialog(context);
      return false;
    }
    final settings = ref.read(aiSettingsStoreProvider);
    if (!await settings.getPrivacyConsentAccepted()) {
      if (!context.mounted) return false;
      final ok = await showAiPrivacyNotice(context);
      if (ok != true) return false;
      await settings.setPrivacyConsentAccepted(true);
      ref.invalidate(aiPrivacyConsentProvider);
      ref.invalidate(aiSettingsStateProvider);
    }
    return true;
  }

  static Future<AiStudyResult?> runWithLoading(
    BuildContext context,
    WidgetRef ref, {
    required AiStudyRequest request,
    Map<String, String> categoryNameToId = const {},
  }) async {
    if (request.sourceText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or provide text for AI first.')),
      );
      return null;
    }
    if (request.sourceText.length > kAiSoftSourceLimit) {
      final cont = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Large text'),
          content: const Text(
            'This note is large. Consider selecting only the part you want '
            'AI to process. Continue anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (cont != true) return null;
    }

    if (!await ensureReady(context, ref)) return null;
    if (!context.mounted) return null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(request.action.loadingMessage)),
            ],
          ),
        ),
      ),
    );

    try {
      final language =
          request.language == AiLanguage.auto
              ? await ref.read(aiSettingsStoreProvider).getLanguage()
              : request.language;
      final result = await ref.read(aiServiceProvider).run(
            AiStudyRequest(
              action: request.action,
              sourceText: request.sourceText,
              language: language,
              rephraseMode: request.rephraseMode,
              organizeMode: request.organizeMode,
              summarizeMode: request.summarizeMode,
              questionType: request.questionType,
              flashcardCount: request.flashcardCount,
              categoryNames: request.categoryNames,
              userPreference: request.userPreference,
              selectedText: request.selectedText,
              shortDescription: request.shortDescription,
            ),
            categoryNameToId: categoryNameToId,
          );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } on AiException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI request failed. Please try again.')),
        );
      }
      return null;
    }
  }

  static String markdownToStoredRich(String markdown) {
    return MarkdownToQuill.toDeltaJson(markdown);
  }
}

// Re-export action enum extensions used by UI.
export '../domain/ai_actions.dart';
