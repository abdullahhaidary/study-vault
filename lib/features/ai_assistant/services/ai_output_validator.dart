import 'dart:convert';

import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';

/// Validates untrusted Gemini JSON / text into domain results.
abstract final class AiOutputValidator {
  static AiTextResult textFromMarkdown(String? raw) {
    final text = _stripCodeFence(raw?.trim() ?? '');
    if (text.isEmpty) {
      throw const AiEmptyResultException();
    }
    return AiTextResult(markdown: text);
  }

  static AiAnnotationDraft parseAnnotation(
    String raw, {
    required Map<String, String> categoryNameToId,
  }) {
    final json = _decodeObject(raw);
    final short = (json['shortDescription'] as String?)?.trim() ?? '';
    final full = (json['fullNote'] as String?)?.trim() ?? '';
    if (short.isEmpty) {
      throw const AiMalformedOutputException(
        'Annotation short description was empty.',
      );
    }
    if (full.length > 50000) {
      throw const AiMalformedOutputException('Annotation note was too long.');
    }
    final suggestedRaw = (json['suggestedCategory'] as String?)?.trim();
    String? categoryId;
    if (suggestedRaw != null && suggestedRaw.isNotEmpty) {
      categoryId = _mapCategory(suggestedRaw, categoryNameToId);
    }
    return AiAnnotationDraft(
      shortDescription: short,
      fullNoteMarkdown: full.isEmpty ? short : full,
      suggestedCategory: categoryId,
    );
  }

  static AiFlashcardsResult parseFlashcards(String raw, {int? expectedCount}) {
    final json = _decodeObject(raw);
    final list = json['cards'];
    if (list is! List || list.isEmpty) {
      throw const AiMalformedOutputException('No flashcards in AI response.');
    }
    final cards = <AiFlashcardDraft>[];
    for (final item in list) {
      if (item is! Map) continue;
      final front = ('${item['front'] ?? ''}').trim();
      final back = ('${item['back'] ?? ''}').trim();
      if (front.isEmpty || back.isEmpty) continue;
      cards.add(AiFlashcardDraft(front: front, back: back));
    }
    if (cards.isEmpty) {
      throw const AiMalformedOutputException('Flashcards were invalid.');
    }
    if (expectedCount != null && cards.length > expectedCount) {
      return AiFlashcardsResult(cards: cards.take(expectedCount).toList());
    }
    return AiFlashcardsResult(cards: cards);
  }

  static AiQuestionsResult parseQuestions(String raw) {
    final json = _decodeObject(raw);
    final list = json['questions'];
    if (list is! List || list.isEmpty) {
      throw const AiMalformedOutputException('No questions in AI response.');
    }
    final questions = <AiQuestionDraft>[];
    for (final item in list) {
      if (item is! Map) continue;
      final q = ('${item['question'] ?? ''}').trim();
      final a = ('${item['answer'] ?? ''}').trim();
      if (q.isEmpty || a.isEmpty) continue;
      List<String>? choices;
      final rawChoices = item['choices'];
      if (rawChoices is List) {
        choices = rawChoices.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
        if (choices.length < 2) choices = null;
      }
      final correct = item['correctIndex'];
      final correctIndex = correct is int
          ? correct
          : int.tryParse('$correct');
      questions.add(
        AiQuestionDraft(
          question: q,
          answer: a,
          choices: choices,
          correctIndex: correctIndex,
          explanation: (item['explanation'] as String?)?.trim(),
        ),
      );
    }
    if (questions.isEmpty) {
      throw const AiMalformedOutputException('Questions were invalid.');
    }
    return AiQuestionsResult(questions: questions);
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    final cleaned = _stripCodeFence(raw.trim());
    if (cleaned.isEmpty) throw const AiEmptyResultException();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw const AiMalformedOutputException();
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  static String _stripCodeFence(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```(?:json|markdown|md)?\s*'), '');
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3).trim();
      }
    }
    return t.trim();
  }

  static String? _mapCategory(
    String suggested,
    Map<String, String> categoryNameToId,
  ) {
    final lower = suggested.toLowerCase();
    for (final entry in categoryNameToId.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    // Loose contains match on known names.
    for (final entry in categoryNameToId.entries) {
      if (lower.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lower)) {
        return entry.value;
      }
    }
    return null; // Unknown → none / General
  }
}

/// JSON schemas passed to Gemini generationConfig.responseSchema.
abstract final class AiResponseSchemas {
  static const annotation = {
    'type': 'object',
    'properties': {
      'shortDescription': {'type': 'string'},
      'fullNote': {'type': 'string'},
      'suggestedCategory': {'type': 'string', 'nullable': true},
    },
    'required': ['shortDescription', 'fullNote'],
  };

  static const flashcards = {
    'type': 'object',
    'properties': {
      'cards': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'front': {'type': 'string'},
            'back': {'type': 'string'},
          },
          'required': ['front', 'back'],
        },
      },
    },
    'required': ['cards'],
  };

  static const questions = {
    'type': 'object',
    'properties': {
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'question': {'type': 'string'},
            'answer': {'type': 'string'},
            'choices': {
              'type': 'array',
              'items': {'type': 'string'},
              'nullable': true,
            },
            'correctIndex': {'type': 'integer', 'nullable': true},
            'explanation': {'type': 'string', 'nullable': true},
          },
          'required': ['question', 'answer'],
        },
      },
    },
    'required': ['questions'],
  };
}
