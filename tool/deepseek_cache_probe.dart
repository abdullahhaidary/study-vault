import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_token_usage.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';

/// Three consecutive DeepSeek requests with a shared PDF-sized prefix.
///
/// Usage:
///   DEEPSEEK_API_KEY=sk-... dart run tool/deepseek_cache_probe.dart
///
/// Optional:
///   DEEPSEEK_MODEL=deepseek-flash
///
/// Does not print the API key or the document text.
void main() async {
  final apiKey = Platform.environment['DEEPSEEK_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln(
      'Set DEEPSEEK_API_KEY and run:\n'
      '  DEEPSEEK_API_KEY=sk-... dart run tool/deepseek_cache_probe.dart',
    );
    exit(1);
  }

  final envModel = Platform.environment['DEEPSEEK_MODEL']?.trim();
  final model = (envModel == null || envModel.isEmpty)
      ? 'deepseek-flash'
      : envModel;

  const paragraph =
      'Gradient descent is an iterative optimization algorithm used in '
      'machine learning. Parameters are updated in the opposite direction of '
      'the gradient of a cost function. The learning rate controls step size. '
      'Local minima, saddle points, and vanishing gradients are common issues. ';
  final document = List.filled(80, paragraph).join();

  final questions = [
    'What is this document about?',
    'Give me the three most important points.',
    'Quiz me on this document.',
  ];

  final client = http.Client();
  try {
    List<Map<String, String>>? previousPrefix;
    for (var i = 0; i < questions.length; i++) {
      final request = AiStudyRequest(
        selection: AiExecutionSelection(
          provider: AiProviderId.deepseek,
          requestedModelId: model,
          resolvedModelId: model,
        ),
        action: AiStudyAction.askAi,
        sourceText: document,
        selectedText: document,
        language: AiLanguage.english,
        customPrompt: questions[i],
      );
      final messages = AiPromptBuilder.deepSeekMessages(request);
      final prefix = messages.take(2).toList(growable: false);
      if (previousPrefix != null) {
        if (previousPrefix[0]['content'] != prefix[0]['content'] ||
            previousPrefix[1]['content'] != prefix[1]['content']) {
          stderr.writeln(
            'ERROR: system+document prefix changed between requests.',
          );
          exit(2);
        }
      }
      previousPrefix = prefix;

      final body = {
        'model': model,
        'messages': messages,
        'max_tokens': 256,
        'stream': false,
        'thinking': {'type': 'disabled'},
      };

      final started = DateTime.now();
      final response = await client.post(
        Uri.parse('https://api.deepseek.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );
      final ms = DateTime.now().difference(started).inMilliseconds;

      stdout.writeln('REQUEST ${i + 1}');
      stdout.writeln('Question: ${questions[i]}');
      stdout.writeln('HTTP ${response.statusCode} (${ms}ms)');
      stdout.writeln('Roles: ${messages.map((m) => m['role']).join(' → ')}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        stdout.writeln('Error body omitted (may contain provider details).');
        stdout.writeln();
        continue;
      }
      final decoded = jsonDecode(response.body);
      final usage = AiTokenUsage.fromProviderResponse(
        decoded,
        model: model,
        provider: 'deepseek',
        durationMs: ms,
      );
      final ratio = usage?.cacheHitRatio;
      stdout.writeln('Prompt: ${usage?.promptTokens ?? 'n/a'}');
      stdout.writeln('Cache hit: ${usage?.cacheHitTokens ?? 'n/a'}');
      stdout.writeln('Cache miss: ${usage?.cacheMissTokens ?? 'n/a'}');
      stdout.writeln('Completion: ${usage?.completionTokens ?? 'n/a'}');
      stdout.writeln('Total: ${usage?.totalTokens ?? 'n/a'}');
      stdout.writeln(
        'Hit ratio: ${ratio == null ? 'n/a' : '${ratio.toStringAsFixed(1)}%'}',
      );
      stdout.writeln();
    }
  } finally {
    client.close();
  }
}
