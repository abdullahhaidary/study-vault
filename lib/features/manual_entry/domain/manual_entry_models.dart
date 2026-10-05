import 'dart:convert';

import '../../ai_questions/domain/quiz_models.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';

/// Thrown when pasted text cannot be understood as a manual-entry bundle.
class ManualEntryFormatException implements Exception {
  const ManualEntryFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Names the user (or the AI) suggested for where content should land.
class ManualEntryTargetHint {
  const ManualEntryTargetHint({
    this.className,
    this.subjectName,
    this.lessonName,
    this.pdfTitle,
  });

  final String? className;
  final String? subjectName;
  final String? lessonName;
  final String? pdfTitle;
}

class ManualStudyMaterial {
  const ManualStudyMaterial({required this.type, required this.markdown});
  final PdfAiMaterialType type;
  final String markdown;
}

class ManualNote {
  const ManualNote({required this.title, required this.markdown});
  final String title;
  final String markdown;
}

class ManualAnnotation {
  const ManualAnnotation({
    required this.page,
    required this.shortText,
    this.fullNoteMarkdown,
    this.categoryKey,
  });

  final int page;
  final String shortText;
  final String? fullNoteMarkdown;

  /// `definition`, `important`, `formula`, `question`, `example`, `exam`,
  /// `confusing`, or null.
  final String? categoryKey;
}

class ManualFlashcard {
  const ManualFlashcard({required this.front, required this.backMarkdown});
  final String front;
  final String backMarkdown;
}

class ManualQuiz {
  const ManualQuiz({
    required this.title,
    required this.difficulty,
    required this.questions,
  });

  final String title;
  final QuizDifficulty difficulty;
  final List<GeneratedQuizQuestion> questions;

  QuizQuestionType get questionType {
    final types = questions.map((q) => q.type).toSet();
    return types.length == 1 ? types.first : QuizQuestionType.mixed;
  }
}

/// One per-PDF Course Review section; every part is optional.
class ManualCourseReviewSection {
  const ManualCourseReviewSection({
    this.lessonName,
    this.pdfTitle,
    this.summary,
    this.explanation,
    this.deepExplanation,
  });

  final String? lessonName;
  final String? pdfTitle;
  final String? summary;
  final String? explanation;
  final String? deepExplanation;

  String get label => [?lessonName, ?pdfTitle].join(' — ');
}

/// The subject-wide condensed review found in the JSON.
class ManualCourseReview {
  const ManualCourseReview({
    this.sections = const [],
    this.examples,
    this.bigPicture,
  });

  final List<ManualCourseReviewSection> sections;
  final String? examples;
  final String? bigPicture;

  int get itemCount =>
      sections.length + (examples == null ? 0 : 1) + (bigPicture == null ? 0 : 1);
}

/// Everything found in one pasted JSON document.
class ManualEntryBundle {
  const ManualEntryBundle({
    required this.target,
    required this.studyMaterials,
    required this.notes,
    required this.annotations,
    required this.flashcards,
    required this.quizzes,
    required this.warnings,
    this.courseReview = const ManualCourseReview(),
  });

  final ManualEntryTargetHint target;
  final List<ManualStudyMaterial> studyMaterials;
  final List<ManualNote> notes;
  final List<ManualAnnotation> annotations;
  final List<ManualFlashcard> flashcards;
  final List<ManualQuiz> quizzes;
  final ManualCourseReview courseReview;

  /// Non-fatal problems (skipped items, unknown fields). Shown to the user.
  final List<String> warnings;

  bool get isEmpty => itemCount == 0;

  /// Study materials and annotations live on a PDF, not directly on a lesson.
  bool get needsPdf => studyMaterials.isNotEmpty || annotations.isNotEmpty;

  /// Everything except the Course Review belongs to one lesson.
  bool get needsLesson =>
      needsPdf || notes.isNotEmpty || flashcards.isNotEmpty || quizzes.isNotEmpty;

  int get itemCount =>
      studyMaterials.length +
      notes.length +
      annotations.length +
      flashcards.length +
      quizzes.length +
      courseReview.itemCount;
}

/// Lenient parser for the format described in `manual_entry_instruction.md`.
///
/// Fatal problems (not JSON, wrong root shape) throw
/// [ManualEntryFormatException]; invalid individual items are skipped and
/// reported through [ManualEntryBundle.warnings].
abstract final class ManualEntryParser {
  static const formatId = 'study-vault-manual-entry';
  static const supportedVersion = 1;

  static const categoryKeys = {
    'definition',
    'important',
    'formula',
    'question',
    'example',
    'exam',
    'confusing',
  };

  static ManualEntryBundle parse(String raw) {
    final text = _stripFence(raw.trim());
    if (text.isEmpty) {
      throw const ManualEntryFormatException('Paste the JSON first.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw ManualEntryFormatException(
        'This is not valid JSON (${e.message.split('\n').first}).',
      );
    }
    if (decoded is! Map) {
      throw const ManualEntryFormatException(
        'The JSON root must be an object { ... }.',
      );
    }
    final root = decoded;
    final warnings = <String>[];
    final format = root['format'];
    if (format != null && format != formatId) {
      warnings.add('Unexpected "format": "$format" (expected "$formatId").');
    }
    final version = root['version'];
    if (version is num && version.toInt() > supportedVersion) {
      warnings.add(
        'Bundle version $version is newer than this app supports '
        '($supportedVersion). Unknown fields are ignored.',
      );
    }

    return ManualEntryBundle(
      target: _target(root['target']),
      studyMaterials: _studyMaterials(root['study_materials'], warnings),
      notes: _notes(root['notes'], warnings),
      annotations: _annotations(root['annotations'], warnings),
      flashcards: _flashcards(root['flashcards'], warnings),
      quizzes: _quizzes(root['quizzes'], warnings),
      courseReview: _courseReview(root['course_review'], warnings),
      warnings: warnings,
    );
  }

  static ManualCourseReview _courseReview(Object? raw, List<String> warnings) {
    if (raw == null) return const ManualCourseReview();
    if (raw is! Map) {
      warnings.add('"course_review" must be an object; skipped.');
      return const ManualCourseReview();
    }
    final sections = _list(raw['sections'], 'course_review.sections', warnings, (
      item,
      index,
    ) {
      final section = ManualCourseReviewSection(
        lessonName: _string(item['lesson']),
        pdfTitle: _string(item['pdf']),
        summary: _string(item['summary']),
        explanation: _string(item['explanation']),
        deepExplanation:
            _string(item['deep_explanation']) ?? _string(item['deep']),
      );
      if (section.summary == null &&
          section.explanation == null &&
          section.deepExplanation == null) {
        warnings.add('Course Review section #${index + 1} is empty; skipped.');
        return null;
      }
      if (section.lessonName == null && section.pdfTitle == null) {
        warnings.add(
          'Course Review section #${index + 1} has no "lesson" or "pdf"; '
          'choose its PDF when reviewing.',
        );
      }
      return section;
    });
    return ManualCourseReview(
      sections: sections,
      examples: _string(raw['examples']),
      bigPicture: _string(raw['big_picture']),
    );
  }

  static String _stripFence(String text) {
    final fence = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n```$');
    final match = fence.firstMatch(text);
    return match == null ? text : match.group(1)!.trim();
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static ManualEntryTargetHint _target(Object? raw) {
    if (raw is! Map) return const ManualEntryTargetHint();
    return ManualEntryTargetHint(
      className: _string(raw['class']),
      subjectName: _string(raw['subject']),
      lessonName: _string(raw['lesson']),
      pdfTitle: _string(raw['pdf']),
    );
  }

  static List<ManualStudyMaterial> _studyMaterials(
    Object? raw,
    List<String> warnings,
  ) {
    if (raw == null) return const [];
    if (raw is! Map) {
      warnings.add('"study_materials" must be an object; skipped.');
      return const [];
    }
    final result = <ManualStudyMaterial>[];
    for (final entry in raw.entries) {
      final type = PdfAiMaterialTypeX.fromStorage('${entry.key}');
      if (type == null) {
        warnings.add('Unknown study material "${entry.key}" skipped.');
        continue;
      }
      final markdown = _string(entry.value);
      if (markdown == null) {
        warnings.add('Study material "${entry.key}" is empty; skipped.');
        continue;
      }
      result.add(ManualStudyMaterial(type: type, markdown: markdown));
    }
    return result;
  }

  static List<ManualNote> _notes(Object? raw, List<String> warnings) {
    return _list(raw, 'notes', warnings, (item, index) {
      final title = _string(item['title']);
      final content = _string(item['content']) ?? _string(item['markdown']);
      if (content == null) {
        warnings.add('Note #${index + 1} has no content; skipped.');
        return null;
      }
      return ManualNote(
        title: title ?? _titleFromMarkdown(content, 'Imported note'),
        markdown: content,
      );
    });
  }

  static List<ManualAnnotation> _annotations(
    Object? raw,
    List<String> warnings,
  ) {
    return _list(raw, 'annotations', warnings, (item, index) {
      final page = _int(item['page']);
      final shortText = _string(item['short_text']) ?? _string(item['title']);
      if (page == null || page < 1) {
        warnings.add('Annotation #${index + 1} needs a page number ≥ 1.');
        return null;
      }
      if (shortText == null) {
        warnings.add('Annotation #${index + 1} needs "short_text"; skipped.');
        return null;
      }
      final category = _string(item['category'])?.toLowerCase();
      if (category != null && !categoryKeys.contains(category)) {
        warnings.add(
          'Annotation #${index + 1}: unknown category "$category" ignored.',
        );
      }
      return ManualAnnotation(
        page: page,
        shortText: shortText.length > 500
            ? shortText.substring(0, 500)
            : shortText,
        fullNoteMarkdown:
            _string(item['full_note']) ?? _string(item['content']),
        categoryKey: categoryKeys.contains(category) ? category : null,
      );
    });
  }

  static List<ManualFlashcard> _flashcards(Object? raw, List<String> warnings) {
    return _list(raw, 'flashcards', warnings, (item, index) {
      final front = _string(item['front']) ?? _string(item['question']);
      final back = _string(item['back']) ?? _string(item['answer']);
      if (front == null || back == null) {
        warnings.add('Flashcard #${index + 1} needs "front" and "back".');
        return null;
      }
      return ManualFlashcard(front: front, backMarkdown: back);
    });
  }

  static List<ManualQuiz> _quizzes(Object? raw, List<String> warnings) {
    return _list(raw, 'quizzes', warnings, (item, index) {
      final label = 'Quiz #${index + 1}';
      final questionsRaw = item['questions'];
      if (questionsRaw is! List || questionsRaw.isEmpty) {
        warnings.add('$label has no questions; skipped.');
        return null;
      }
      final questions = <GeneratedQuizQuestion>[];
      for (var i = 0; i < questionsRaw.length; i++) {
        final q = questionsRaw[i];
        if (q is! Map) {
          warnings.add('$label question #${i + 1} is not an object.');
          continue;
        }
        final parsed = _question(q, '$label question #${i + 1}', warnings);
        if (parsed != null) questions.add(parsed);
      }
      if (questions.isEmpty) {
        warnings.add('$label has no valid questions; skipped.');
        return null;
      }
      return ManualQuiz(
        title: _string(item['title']) ?? 'Imported quiz ${index + 1}',
        difficulty: QuizDifficultyX.fromStorage(
          _string(item['difficulty'])?.toLowerCase(),
        ),
        questions: questions,
      );
    });
  }

  static GeneratedQuizQuestion? _question(
    Map q,
    String label,
    List<String> warnings,
  ) {
    final question = _string(q['question']);
    if (question == null) {
      warnings.add('$label has no "question" text; skipped.');
      return null;
    }
    final typeRaw = (_string(q['type']) ?? 'short_answer').toLowerCase();
    final type = switch (typeRaw) {
      'mcq' || 'multiple_choice' => QuizQuestionType.mcq,
      'true_false' || 'boolean' => QuizQuestionType.trueFalse,
      'fill_blank' || 'fill_in_the_blank' => QuizQuestionType.fillBlank,
      'short_answer' || 'open' => QuizQuestionType.shortAnswer,
      _ => null,
    };
    if (type == null) {
      warnings.add('$label: unknown type "$typeRaw"; skipped.');
      return null;
    }
    final difficulty = QuizDifficultyX.fromStorage(
      _string(q['difficulty'])?.toLowerCase(),
    );
    final explanation = _string(q['explanation']) ?? '';
    final page = _int(q['page']);
    final correctRaw = q.containsKey('correct') ? q['correct'] : q['answer'];

    switch (type) {
      case QuizQuestionType.mcq:
        final options = q['options'];
        if (options is! List || options.length != 4) {
          warnings.add('$label: MCQ needs exactly 4 "options"; skipped.');
          return null;
        }
        final texts = options.map((o) => _string(o)).toList();
        if (texts.any((t) => t == null)) {
          warnings.add('$label: every option must be text; skipped.');
          return null;
        }
        int? index;
        if (correctRaw is num) {
          index = correctRaw.toInt();
        } else if (correctRaw is String) {
          final letter = correctRaw.trim().toUpperCase();
          index = letter.length == 1 && 'ABCD'.contains(letter)
              ? 'ABCD'.indexOf(letter)
              : texts.indexWhere(
                  (t) => t!.toLowerCase() == correctRaw.trim().toLowerCase(),
                );
          if (index < 0) index = int.tryParse(letter);
        }
        if (index == null || index < 0 || index > 3) {
          warnings.add(
            '$label: "correct" must be an option index 0–3 or A–D; skipped.',
          );
          return null;
        }
        return GeneratedQuizQuestion(
          type: type,
          question: question,
          correctAnswer: index,
          explanation: explanation,
          difficulty: difficulty,
          options: texts.cast<String>(),
          sourcePage: page,
        );
      case QuizQuestionType.trueFalse:
        bool? value;
        if (correctRaw is bool) value = correctRaw;
        if (correctRaw is String) {
          value = switch (correctRaw.trim().toLowerCase()) {
            'true' => true,
            'false' => false,
            _ => null,
          };
        }
        if (value == null) {
          warnings.add('$label: "correct" must be true or false; skipped.');
          return null;
        }
        return GeneratedQuizQuestion(
          type: type,
          question: question,
          correctAnswer: value,
          explanation: explanation,
          difficulty: difficulty,
          sourcePage: page,
        );
      case QuizQuestionType.shortAnswer:
      case QuizQuestionType.fillBlank:
        final answer = _string(correctRaw);
        if (answer == null) {
          warnings.add('$label needs an "answer"; skipped.');
          return null;
        }
        return GeneratedQuizQuestion(
          type: type,
          question: question,
          correctAnswer: answer,
          explanation: explanation,
          difficulty: difficulty,
          sourcePage: page,
        );
      case QuizQuestionType.mixed:
        return null;
    }
  }

  static List<T> _list<T>(
    Object? raw,
    String key,
    List<String> warnings,
    T? Function(Map item, int index) build,
  ) {
    if (raw == null) return const [];
    if (raw is! List) {
      warnings.add('"$key" must be a list; skipped.');
      return const [];
    }
    final result = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        warnings.add('"$key" item #${i + 1} is not an object; skipped.');
        continue;
      }
      final built = build(item, i);
      if (built != null) result.add(built);
    }
    return result;
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _titleFromMarkdown(String markdown, String fallback) {
    final firstLine = markdown
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^#+\s*'), '').trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => fallback);
    return firstLine.length > 120 ? firstLine.substring(0, 120) : firstLine;
  }
}
