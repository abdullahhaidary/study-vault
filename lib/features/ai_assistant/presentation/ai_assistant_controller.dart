import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import '../domain/annotation_ai_context.dart';
import '../services/markdown_to_quill.dart';
import 'ai_missing_key_dialog.dart';
import 'ai_privacy_dialog.dart';

/// Shared entry point for user-initiated AI actions.
abstract final class AiAssistantController {
  static bool _requestInFlight = false;

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
    AnnotationAiContext? annotationContext,
  }) async {
    if (_requestInFlight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An AI request is already in progress.')),
      );
      return null;
    }

    final sourceLen = request.effectiveSourceLength;
    if (request.sourceText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or provide text for AI first.')),
      );
      return null;
    }
    if (sourceLen > kAiSoftSourceLimit) {
      final cont = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Large text'),
          content: const Text(
            'This selection is large. Consider selecting only the part you want '
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

    if (!context.mounted || !await ensureReady(context, ref)) return null;
    if (!context.mounted) return null;

    var cancelled = false;
    _requestInFlight = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(request.action.loadingMessage)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    try {
      final language = request.language == AiLanguage.auto
          ? await ref.read(aiSettingsStoreProvider).getLanguage()
          : request.language;

      final AiStudyResult result;
      if (annotationContext != null) {
        result = await ref
            .read(annotationAiServiceProvider)
            .run(
              context: annotationContext,
              action: request.action,
              rephraseMode: request.rephraseMode,
              organizeMode: request.organizeMode,
              summarizeMode: request.summarizeMode,
              flashcardCount: request.flashcardCount,
              categoryNames: request.categoryNames,
              customPrompt: request.customPrompt,
              conversation: request.conversation,
              translateTarget: request.translateTarget,
              languageOverride: language,
              categoryNameToId: categoryNameToId,
            );
      } else {
        result = await ref
            .read(aiServiceProvider)
            .run(
              request.copyWith(language: language),
              categoryNameToId: categoryNameToId,
            );
      }

      if (cancelled) {
        return null;
      }
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } on AiCancelledException {
      return null;
    } on AiException catch (e) {
      if (!cancelled && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    } catch (_) {
      if (!cancelled && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI request failed. Please try again.')),
        );
      }
      return null;
    } finally {
      _requestInFlight = false;
    }
  }

  static String markdownToStoredRich(String markdown) {
    return MarkdownToQuill.toDeltaJson(markdown);
  }
}
