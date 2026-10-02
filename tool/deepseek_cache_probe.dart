import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/domain/deepseek_usage.dart';

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
    for (var i = 0; i < questions.length; i++) {
      final request = AiStudyRequest(
        action: AiStudyAction.askAi,
        sourceText: document,
        selectedText: document,
        language: AiLanguage.english,
        customPrompt: questions[i],
      );
      final body = {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': AiPromptBuilder.systemPreamble(
              language: request.language,
            ),
          },
          {
            'role': 'user',
            'content': AiPromptBuilder.userContentForRequest(request),
          },
        ],
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

      stdout.writeln('--- Request ${i + 1}: ${questions[i]} ---');
      stdout.writeln('HTTP ${response.statusCode} (${ms}ms)');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        stdout.writeln('Error body omitted (may contain provider details).');
        continue;
      }
      final decoded = jsonDecode(response.body);
      final usage = DeepSeekPromptUsage.fromResponse(decoded);
      stdout.writeln(
        (usage ?? const DeepSeekPromptUsage()).formatLog(
          model: model,
          durationMs: ms,
        ),
      );
      stdout.writeln();
    }
  } finally {
    client.close();
  }
}
