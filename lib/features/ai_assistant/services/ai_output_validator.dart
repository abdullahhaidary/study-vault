import 'dart:convert';

import '../../ai_questions/domain/quiz_models.dart';
import '../domain/ai_actions.dart';
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

  /// Strict quiz JSON validation. Rejects invalid items; never returns a
  /// partially-valid quiz when [expectedCount] is set and not met.
  static AiQuestionsResult parseQuestions(
    String raw, {
    int? expectedCount,
    AiQuestionType? requestedType,
  }) {
    _debugLog(
      'Quiz parse start rawChars=${raw.length} expected=$expectedCount '
      'requestedType=${requestedType?.name ?? 'any'}',
    );
    try {
      final json = _decodeObject(raw);
      final title = ('${json['title'] ?? 'Generated Quiz'}').trim();
      final list = json['questions'];
      if (list is! List || list.isEmpty) {
        throw const AiMalformedOutputException('No questions in AI response.');
      }

      final generated = <GeneratedQuizQuestion>[];
      final drafts = <AiQuestionDraft>[];

      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is! Map) {
          throw AiMalformedOutputException(
            'Question entry #$i was not an object.',
          );
        }
        final map = Map<String, dynamic>.from(item);
        try {
          final parsed = _parseOneQuestion(map, requestedType: requestedType);
          generated.add(parsed);
          drafts.add(_toDraft(parsed));
          _debugLog(
            'Quiz parse q#$i type=${parsed.type.storageValue} '
            'opts=${parsed.options.length} ok',
          );
        } on AiException catch (e) {
          _debugLog(
            'Quiz parse q#$i FAILED: ${e.message} '
            'rawType=${map['type']} correct=${map['correctAnswer'] ?? map['correctIndex']} '
            'options=${_describeOptions(map['options'] ?? map['choices'])}',
          );
          rethrow;
        }
      }

      if (expectedCount != null && generated.length != expectedCount) {
        throw AiMalformedOutputException(
          'Expected exactly $expectedCount questions, '
          'got ${generated.length}.',
        );
      }

      _debugLog(
        'Quiz parse ok title="${title.isEmpty ? 'Generated Quiz' : title}" '
        'count=${generated.length} '
        'mcq=${generated.where((q) => q.isMcq).length}',
      );

      return AiQuestionsResult(
        title: title.isEmpty ? 'Generated Quiz' : title,
        questions: drafts,
        generated: GeneratedQuiz(
          title: title.isEmpty ? 'Generated Quiz' : title,
          questions: generated,
        ),
      );
    } on AiException catch (e) {
      _debugLog('Quiz parse aborted: ${e.message}');
      rethrow;
    }
  }

  static GeneratedQuizQuestion _parseOneQuestion(
    Map<String, dynamic> item, {
    AiQuestionType? requestedType,
  }) {
    final type = _parseType(item['type'], requestedType);
    final question = ('${item['question'] ?? ''}').trim();
    if (question.isEmpty) {
      throw const AiMalformedOutputException('A question was empty.');
    }

    final explanation = ('${item['explanation'] ?? ''}').trim();
    if (explanation.isEmpty) {
      throw const AiMalformedOutputException(
        'A question was missing an explanation.',
      );
    }

    final difficulty = _parseDifficulty(item['difficulty']);
    final sourcePage = _parseSourcePage(item['sourcePage']);

    switch (type) {
      case QuizQuestionType.mcq:
        return _parseMcq(
          question: question,
          explanation: explanation,
          difficulty: difficulty,
          sourcePage: sourcePage,
          item: item,
        );
      case QuizQuestionType.trueFalse:
        return _parseTrueFalse(
          question: question,
          explanation: explanation,
          difficulty: difficulty,
          sourcePage: sourcePage,
          item: item,
        );
      case QuizQuestionType.shortAnswer:
      case QuizQuestionType.fillBlank:
        return _parseTextAnswer(
          type: type,
          question: question,
          explanation: explanation,
          difficulty: difficulty,
          sourcePage: sourcePage,
          item: item,
        );
      case QuizQuestionType.mixed:
        throw const AiMalformedOutputException(
          'Individual questions cannot have type "mixed".',
        );
    }
  }

  static GeneratedQuizQuestion _parseMcq({
    required String question,
    required String explanation,
    required QuizDifficulty difficulty,
    required int? sourcePage,
    required Map<String, dynamic> item,
  }) {
    final rawOptions = item['options'] ?? item['choices'];
    if (rawOptions is! List) {
      throw const AiMalformedOutputException('MCQ options were missing.');
    }
    final options = rawOptions
        .map(_optionText)
        .where((e) => e.isNotEmpty)
        .toList();
    if (options.length != 4) {
      throw AiMalformedOutputException(
        'MCQ must have exactly 4 options (got ${options.length}).',
      );
    }
    if (options.toSet().length != 4) {
      throw const AiMalformedOutputException('MCQ options must be unique.');
    }

    final correct = item['correctAnswer'] ?? item['correctIndex'];
    final index = _resolveMcqCorrectIndex(correct, options);
    if (index == null) {
      throw AiMalformedOutputException(
        'MCQ correctAnswer must be 0–3, A–D, or match an option '
        '(got: ${correct ?? '(missing)'}).',
      );
    }

    return GeneratedQuizQuestion(
      type: QuizQuestionType.mcq,
      question: question,
      options: options,
      correctAnswer: index,
      explanation: explanation,
      difficulty: difficulty,
      sourcePage: sourcePage,
    );
  }

  /// Accepts 0-based indexes, 1-based `4`, letters A–D, or option text.
  static int? _resolveMcqCorrectIndex(Object? correct, List<String> options) {
    if (correct == null) return null;

    if (correct is num) {
      final n = correct.round();
      if (n >= 0 && n <= 3) return n;
      // Unambiguous 1-based last option.
      if (n == 4) return 3;
      return null;
    }

    final raw = '$correct'.trim();
    if (raw.isEmpty) return null;

    final asInt = int.tryParse(raw);
    if (asInt != null) {
      if (asInt >= 0 && asInt <= 3) return asInt;
      if (asInt == 4) return 3;
    }

    final letter = RegExp(
      r'^(?:option\s*)?[\(\[]?([a-d])[\)\]\.\:]?$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (letter != null) {
      return letter.group(1)!.toLowerCase().codeUnitAt(0) - 97;
    }

    final lower = raw.toLowerCase();
    final exact = options.indexWhere((o) => o.toLowerCase() == lower);
    if (exact >= 0) return exact;

    final partial = <int>[];
    for (var i = 0; i < options.length; i++) {
      final o = options[i].toLowerCase();
      if (o.contains(lower) || lower.contains(o)) partial.add(i);
    }
    if (partial.length == 1) return partial.first;

    return null;
  }

  static String _optionText(Object? value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final nested =
          map['text'] ?? map['label'] ?? map['option'] ?? map['value'];
      if (nested != null) return '$nested'.trim();
    }
    return '$value'.trim();
  }

  static String _describeOptions(Object? raw) {
    if (raw is! List) return 'missing(${raw.runtimeType})';
    return 'len=${raw.length}';
  }

  static void _debugLog(String message) {
    assert(() {
      // ignore: avoid_print
      print('AI quiz: $message');
      return true;
    }());
  }

  static GeneratedQuizQuestion _parseTrueFalse({
    required String question,
    required String explanation,
    required QuizDifficulty difficulty,
    required int? sourcePage,
    required Map<String, dynamic> item,
  }) {
    final raw = item['correctAnswer'];
    final bool? value = switch (raw) {
      bool b => b,
      String s => switch (s.trim().toLowerCase()) {
        'true' || 't' || 'yes' || '1' => true,
        'false' || 'f' || 'no' || '0' => false,
        _ => null,
      },
      int n =>
        n == 1
            ? true
            : n == 0
            ? false
            : null,
      _ => null,
    };
    if (value == null) {
      throw const AiMalformedOutputException(
        'True/False correctAnswer must be a boolean.',
      );
    }
    return GeneratedQuizQuestion(
      type: QuizQuestionType.trueFalse,
      question: question,
      correctAnswer: value,
      explanation: explanation,
      difficulty: difficulty,
      sourcePage: sourcePage,
      options: const ['True', 'False'],
    );
  }

  static GeneratedQuizQuestion _parseTextAnswer({
    required QuizQuestionType type,
    required String question,
    required String explanation,
    required QuizDifficulty difficulty,
    required int? sourcePage,
    required Map<String, dynamic> item,
  }) {
    final answer = ('${item['correctAnswer'] ?? item['answer'] ?? ''}').trim();
    if (answer.isEmpty) {
      throw const AiMalformedOutputException(
        'Short/fill-blank answer was empty.',
      );
    }
    return GeneratedQuizQuestion(
      type: type,
      question: question,
      correctAnswer: answer,
      explanation: explanation,
      difficulty: difficulty,
      sourcePage: sourcePage,
    );
  }

  static QuizQuestionType _parseType(
    Object? raw,
    AiQuestionType? requestedType,
  ) {
    final value = ('${raw ?? ''}').trim().toLowerCase();
    final parsed = switch (value) {
      'mcq' || 'multiple_choice' || 'multiple-choice' => QuizQuestionType.mcq,
      'true_false' ||
      'truefalse' ||
      'true/false' ||
      'tf' => QuizQuestionType.trueFalse,
      'short_answer' ||
      'shortanswer' ||
      'short' => QuizQuestionType.shortAnswer,
      'fill_blank' ||
      'fill_in_the_blank' ||
      'fill-in-the-blank' ||
      'fib' => QuizQuestionType.fillBlank,
      '' when requestedType != null && requestedType != AiQuestionType.mixed =>
        _mapRequestedType(requestedType),
      _ => null,
    };
    if (parsed == null) {
      throw AiMalformedOutputException(
        'Unsupported question type: ${raw ?? '(missing)'}.',
      );
    }
    return parsed;
  }

  static QuizQuestionType _mapRequestedType(AiQuestionType type) {
    return switch (type) {
      AiQuestionType.mcq => QuizQuestionType.mcq,
      AiQuestionType.trueFalse => QuizQuestionType.trueFalse,
      AiQuestionType.shortAnswer => QuizQuestionType.shortAnswer,
      AiQuestionType.fillBlank => QuizQuestionType.fillBlank,
      AiQuestionType.mixed => QuizQuestionType.shortAnswer,
    };
  }

  static QuizDifficulty _parseDifficulty(Object? raw) {
    final value = ('${raw ?? ''}').trim().toLowerCase();
    return switch (value) {
      'easy' => QuizDifficulty.easy,
      'hard' => QuizDifficulty.hard,
      'medium' || '' => QuizDifficulty.medium,
      'mixed' => QuizDifficulty.mixed,
      _ => QuizDifficulty.medium,
    };
  }

  static int? _parseSourcePage(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    return int.tryParse('$raw');
  }

  static AiQuestionDraft _toDraft(GeneratedQuizQuestion q) {
    return AiQuestionDraft(
      question: q.question,
      answer: q.correctAnswerStorage,
      type: q.type,
      choices: q.options.isEmpty ? null : q.options,
      correctIndex: q.isMcq ? q.correctAnswer as int : null,
      explanation: q.explanation,
      difficulty: q.difficulty,
      sourcePage: q.sourcePage,
    );
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
    for (final entry in categoryNameToId.entries) {
      if (lower.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lower)) {
        return entry.value;
      }
    }
    return null;
  }
}

/// JSON schemas for Gemini structured output (`responseJsonSchema`).
abstract final class AiResponseSchemas {
  static const annotation = {
    'type': 'object',
    'properties': {
      'shortDescription': {'type': 'string'},
      'fullNote': {'type': 'string'},
      'suggestedCategory': {'type': 'string'},
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
      'title': {'type': 'string'},
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['mcq', 'true_false', 'short_answer', 'fill_blank'],
            },
            'question': {'type': 'string'},
            'options': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'correctAnswer': {},
            'explanation': {'type': 'string'},
            'difficulty': {
              'type': 'string',
              'enum': ['easy', 'medium', 'hard'],
            },
            'sourcePage': {'type': 'integer'},
          },
          'required': [
            'type',
            'question',
            'correctAnswer',
            'explanation',
            'difficulty',
          ],
        },
      },
    },
    'required': ['title', 'questions'],
  };
}
