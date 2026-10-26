import 'dart:io';

import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_token_usage.dart';
import 'ai_output_validator.dart';
import 'ai_prompt_builder.dart';
import 'ai_service.dart';
import 'pocket_client.dart';

/// Study actions sent to the local Pocket window.
class PocketAiService implements AiService {
  PocketAiService({required this.settings, PocketClient? client})
    : _client = client ?? PocketClient(settings: settings);

  final AiSettingsStore settings;
  final PocketClient _client;

  static const _provider = AiProviderId.pocket;

  @override
  Future<bool> get isConfigured async => true;

  @override
  Future<void> testConnection({Duration timeout = const Duration(seconds: 5)}) {
    return _client.checkHealth(timeout: timeout);
  }

  @override
  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(minutes: 5),
  }) async {
    _assertSource(request);
    if ((request.action == AiStudyAction.askAi ||
            request.action == AiStudyAction.customPrompt) &&
        (request.customPrompt == null ||
            request.customPrompt!.trim().isEmpty)) {
      throw const AiMalformedOutputException(
        'Enter a question or custom prompt first.',
      );
    }
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final preference = await settings.styleForSend(provider: _provider);
    final prompt = AiPromptBuilder.forRequest(
      request.copyWith(userPreference: request.userPreference ?? preference),
    );
    final text = await _send(
      modelId: request.selection.resolvedModelId,
      message: prompt,
      image: request.image,
      timeout: timeout,
    );
    final parsed = switch (request.action) {
      AiStudyAction.explain ||
      AiStudyAction.simplify ||
      AiStudyAction.rephrase ||
      AiStudyAction.fixGrammar ||
      AiStudyAction.organize ||
      AiStudyAction.summarize ||
      AiStudyAction.define ||
      AiStudyAction.giveExample ||
      AiStudyAction.translate ||
      AiStudyAction.askAi ||
      AiStudyAction.customPrompt ||
      AiStudyAction.keyConcepts ||
      AiStudyAction.examPoints => AiOutputValidator.textFromMarkdown(text),
      AiStudyAction.createAnnotation => AiOutputValidator.parseAnnotation(
        text,
        categoryNameToId: categoryNameToId,
      ),
      AiStudyAction.generateFlashcards => AiOutputValidator.parseFlashcards(
        text,
        expectedCount: request.flashcardCount,
      ),
      AiStudyAction.generateQuestions => AiOutputValidator.parseQuestions(
        text,
        expectedCount: request.questionCount,
        requestedType: request.questionType,
      ),
    };
    final usage = AiTokenUsage(
      model: request.selection.persistedModelId,
      provider: _provider.storageValue,
    );
    return switch (parsed) {
      AiTextResult r => r.withUsage(usage),
      AiAnnotationDraft r => r.withUsage(usage),
      AiFlashcardsResult r => r.withUsage(usage),
      AiQuestionsResult r => r.withUsage(usage),
    };
  }

  @override
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final result = await run(request.toStudyRequest(), timeout: timeout);
    if (result is! AiQuestionsResult) {
      throw const AiMalformedOutputException(
        'Pocket did not return quiz questions.',
      );
    }
    return result;
  }

  /// Whole-document completion used by materials, translations, books, and quizzes.
  Future<AiTextResult> completeDocumentMessages({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    Duration timeout = const Duration(minutes: 5),
    void Function(String partialText)? onPartialText,
  }) async {
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final prompt = _joinMessages(messages);
    if (prompt.trim().isEmpty) {
      throw const AiMalformedOutputException('The document prompt is empty.');
    }
    var text = '';
    await for (final reply in _client.watch(
      modelId: selection.resolvedModelId,
      message: prompt,
      timeout: timeout,
    )) {
      text = reply.text;
      onPartialText?.call(text);
    }
    return AiTextResult(
      markdown: text,
      usage: AiTokenUsage(
        model: selection.persistedModelId,
        provider: _provider.storageValue,
      ),
    );
  }

  Future<String> _send({
    required String modelId,
    required String message,
    AiStudyImage? image,
    required Duration timeout,
  }) async {
    String? staged;
    try {
      if (image != null) staged = await _stageImage(image);
      final reply = await _client.send(
        modelId: modelId,
        message: message,
        files: [?staged],
        timeout: timeout,
      );
      return reply.text;
    } finally {
      if (staged != null) {
        try {
          await File(staged).delete();
        } on FileSystemException {
          // The picture was only a temporary upload for Pocket.
        }
      }
    }
  }

  Future<String> _stageImage(AiStudyImage image) async {
    if (image.bytes.isEmpty) {
      throw const AiMalformedOutputException(
        'Could not render this PDF page as an image.',
      );
    }
    if (image.bytes.length > kAiMaxPageImageBytes) {
      throw const AiSourceTooLargeException();
    }
    final ext = switch (image.mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      _ => '.jpg',
    };
    final file = File(
      '${Directory.systemTemp.path}/study-vault-pocket-'
      '${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    await file.writeAsBytes(image.bytes, flush: true);
    return file.path;
  }

  String _joinMessages(List<Map<String, String>> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      final content = (message['content'] ?? '').trim();
      if (content.isEmpty) continue;
      final role = switch (message['role']) {
        'system' => 'System',
        'assistant' => 'Assistant',
        _ => 'User',
      };
      buffer.writeln('$role:');
      buffer.writeln(content);
      buffer.writeln();
    }
    if (buffer.isEmpty) return '';
    buffer.writeln(
      'Reply as the assistant to the latest user message. '
      'Return only the answer that was requested.',
    );
    return buffer.toString();
  }

  void _assertSource(AiStudyRequest request) {
    if (request.hasPageImage) {
      if (request.image!.bytes.isEmpty) {
        throw const AiMalformedOutputException(
          'Could not render this PDF page as an image.',
        );
      }
      return;
    }
    if (request.sourceText.trim().isEmpty &&
        (request.selectedText ?? '').trim().isEmpty) {
      throw const AiEmptySelectionException();
    }
    if (request.sourceText.length > kAiHardSourceLimit &&
        (request.selectedText ?? request.sourceText).length >
            kAiHardSourceLimit) {
      throw const AiSourceTooLargeException();
    }
  }
}
