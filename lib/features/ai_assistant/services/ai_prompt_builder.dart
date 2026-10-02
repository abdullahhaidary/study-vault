import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';

/// Builds study-action prompts (provider-agnostic single source of truth).
///
/// Layout is cache-friendly for DeepSeek prefix matching:
/// 1. Stable system preamble
/// 2. Stable document / selection text
/// 3. Prior conversation (appended, never rewritten)
/// 4. Current task / student question
abstract final class AiPromptBuilder {
  static const _preserveRules = '''
Preserve-meaning rules (mandatory):
- Preserve the original meaning.
- Do not invent unsupported facts or academic claims.
- Do not remove important details.
- Preserve equations, formulas, symbols (θ, α, ∇, etc.), and code.
- Preserve technical English terms (Gradient Descent, Learning Rate, Precision, Recall, Cost Function, API, etc.) — do not translate them unless explicitly asked.
- Preserve the source language unless a language override is requested.
- Preserve numbers, variable names, and code identifiers unchanged.
''';

  static const _annotationStudyRole = '''
You are assisting a student studying educational material.

Use the selected text as the primary source.
Use surrounding context only to clarify meaning.
Do not invent unsupported facts.
Keep terminology consistent with the source.
When useful, explain difficult terms.
Return concise but educational answers.
''';

  static String systemPreamble({
    required AiLanguage language,
    String? userPreference,
  }) {
    final lang = switch (language) {
      AiLanguage.auto =>
        'Respond mainly in the language of the user request when clear; '
            'otherwise follow the source language. For mixed Persian/Dari + English, '
            'keep the same mix and preserve English technical terms.',
      AiLanguage.english => 'Respond in English.',
      AiLanguage.persianDari =>
        'Respond in Persian/Dari, but keep English technical terms and formulas unchanged.',
    };
    final preference = (userPreference == null || userPreference.trim().isEmpty)
        ? ''
        : '\nUser study preference: ${userPreference.trim()}\n';
    return 'You are Study Vault AI Assistant for university students.\n'
        '$_annotationStudyRole'
        '$lang\n'
        '$_preserveRules'
        '$preference';
  }

  /// Formats selected text + optional surrounding page window + page number.
  static String materialBlock(AiStudyRequest request) {
    final selected = (request.selectedText ?? request.sourceText).trim();
    final buffer = StringBuffer();
    if (request.pageNumber != null || request.image?.pageNumber != null) {
      buffer.writeln(
        'PAGE: ${request.pageNumber ?? request.image!.pageNumber}',
      );
      buffer.writeln();
    }
    if (request.hasPageImage) {
      buffer.writeln(
        'A JPEG of this single PDF page/slide is attached. '
        'Use the visual (text, diagrams, photos). Do not invent other pages.',
      );
      buffer.writeln();
    }
    buffer.writeln(
      request.hasPageImage ? 'PAGE TEXT (may be empty):' : 'SELECTED TEXT:',
    );
    buffer.writeln(selected);
    final surrounding = request.surroundingText?.trim();
    if (!request.hasPageImage &&
        surrounding != null &&
        surrounding.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'SURROUNDING CONTEXT (clarify meaning only; do not digress):',
      );
      buffer.writeln(surrounding);
    }
    if (request.shortDescription != null &&
        request.shortDescription!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('EXISTING SHORT DESCRIPTION:');
      buffer.writeln(request.shortDescription!.trim());
    }
    return buffer.toString().trim();
  }

  static String _conversationBlock(AiStudyRequest request) {
    if (request.conversation.isEmpty) return '';
    // Bound context growth for all providers.
    const maxTurns = 8;
    final turns = request.conversation.length > maxTurns
        ? request.conversation.sublist(request.conversation.length - maxTurns)
        : request.conversation;
    final buffer = StringBuffer('\nPRIOR CONVERSATION (same selection):\n');
    for (final turn in turns) {
      buffer.writeln('Student: ${turn.userMessage}');
      buffer.writeln('Assistant: ${turn.assistantMarkdown}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Stable source/document section placed before the varying task/question
  /// so DeepSeek prefix cache can reuse PDF context across follow-ups.
  static String _sourceBlock(AiStudyRequest request) {
    return switch (request.action) {
      AiStudyAction.organize => 'NOTE:\n${request.sourceText}',
      AiStudyAction.generateQuestions => _questionsSourceBlock(request),
      _ => materialBlock(request),
    };
  }

  static String _questionsSourceBlock(AiStudyRequest request) {
    final buffer = StringBuffer();
    if (request.hasPageImage) {
      buffer.writeln(
        'A JPEG of a single PDF page/slide is attached. '
        'Generate questions from that visual (including diagrams). '
        'Do not invent other pages.',
      );
      buffer.writeln();
    }
    buffer.writeln('SOURCE MATERIAL:');
    buffer.write(request.sourceText);
    return buffer.toString().trim();
  }

  static bool _includeConversation(AiStudyAction action) => switch (action) {
    AiStudyAction.fixGrammar ||
    AiStudyAction.createAnnotation ||
    AiStudyAction.generateFlashcards ||
    AiStudyAction.generateQuestions => false,
    _ => true,
  };

  /// Latest user turn for DeepSeek multi-turn (question / task only).
  ///
  /// Document content lives in a separate earlier user message so this can
  /// change without busting the reusable prefix.
  static String deepSeekLatestUserContent(AiStudyRequest request) {
    return switch (request.action) {
      AiStudyAction.askAi ||
      AiStudyAction.customPrompt => (request.customPrompt ?? '').trim(),
      _ => _taskBlock(request),
    };
  }

  /// Real multi-turn OpenAI-style messages for DeepSeek prefix caching.
  ///
  /// Order: system → stable document → prior Q/A → latest user turn.
  static List<Map<String, String>> deepSeekMessages(AiStudyRequest request) {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': systemPreamble(
          language: preambleLanguage(request),
          userPreference: request.userPreference,
        ),
      },
      {'role': 'user', 'content': _sourceBlock(request)},
    ];

    if (_includeConversation(request.action) &&
        request.conversation.isNotEmpty) {
      const maxTurns = 8;
      final turns = request.conversation.length > maxTurns
          ? request.conversation.sublist(request.conversation.length - maxTurns)
          : request.conversation;
      for (final turn in turns) {
        final q = turn.userMessage.trim();
        final a = turn.assistantMarkdown.trim();
        if (q.isNotEmpty) {
          messages.add({'role': 'user', 'content': q});
        }
        if (a.isNotEmpty) {
          messages.add({'role': 'assistant', 'content': a});
        }
      }
    }

    final latest = deepSeekLatestUserContent(request);
    if (latest.isNotEmpty) {
      messages.add({'role': 'user', 'content': latest});
    }
    return messages;
  }

  /// User-message body: document + prior turns + current task/question.
  ///
  /// Used by Gemini (single-content) and as a fallback. DeepSeek prefers
  /// [deepSeekMessages] for follow-ups.
  static String userContentForRequest(AiStudyRequest request) {
    final buffer = StringBuffer()
      ..writeln(_sourceBlock(request))
      ..write(
        _includeConversation(request.action) ? _conversationBlock(request) : '',
      )
      ..writeln()
      ..write(_taskBlock(request));
    return buffer.toString().trim();
  }

  static String _taskBlock(AiStudyRequest request) {
    return switch (request.action) {
      AiStudyAction.explain =>
        'Task: Explain the selected text clearly for a university student.\n'
            'Requirements:\n'
            '- explain the meaning\n'
            '- explain difficult terminology\n'
            '- explain why it matters\n'
            '- use a simple example when helpful\n'
            '- do not introduce unrelated concepts\n'
            'Return markdown only (no JSON).',
      AiStudyAction.simplify =>
        'Task: Rewrite/explain the selected material in simpler language '
            'without changing its meaning.\n'
            'Keep technical terms and formulas. Return markdown only.',
      AiStudyAction.rephrase => _rephraseTask(request),
      AiStudyAction.fixGrammar =>
        'Task: Fix grammar and wording while preserving meaning and technical terms.\n'
            'Return markdown only.',
      AiStudyAction.organize => _organizeTask(request),
      AiStudyAction.summarize => _summarizeTask(request),
      AiStudyAction.define =>
        'Task: Identify the main concept or term in the selected text and provide:\n'
            '- definition\n'
            '- meaning in this context\n'
            '- short example\n'
            'Return markdown only.',
      AiStudyAction.giveExample =>
        'Task: Provide one or two examples that directly demonstrate the selected concept.\n'
            'Keep examples concrete and tied to the source. Return markdown only.',
      AiStudyAction.keyConcepts =>
        'Task: Extract the most important key concepts / terms from the source.\n'
            'Requirements:\n'
            '- Return a short markdown list (prefer 3–8 items).\n'
            '- Each item: **Term** — concise definition grounded in the source.\n'
            '- Preserve formulas, variable names, and technical English terms.\n'
            '- Do not invent concepts not supported by the source.\n'
            'Return markdown only.',
      AiStudyAction.examPoints =>
        'Task: Help the student prepare for exams based ONLY on this source.\n'
            'Return concise markdown with these sections when useful:\n'
            '- Important definition / concept\n'
            '- Common confusion\n'
            '- One short exam-style practice question (do NOT claim this predicts a real exam)\n'
            'Stay grounded in the source. Preserve formulas and technical terms.\n'
            'Return markdown only.',
      AiStudyAction.translate => _translateTask(request),
      AiStudyAction.askAi =>
        'Task: Answer the student question about the selected study material.\n'
            'Base the answer on the selected text and surrounding context only.\n'
            'Return markdown only.\n\n'
            'STUDENT QUESTION:\n${(request.customPrompt ?? '').trim()}',
      AiStudyAction.customPrompt =>
        'Task: Follow the student custom instruction for the selected material.\n'
            'Stay grounded in the selected text and surrounding context.\n'
            'Return markdown only.\n\n'
            'CUSTOM INSTRUCTION:\n${(request.customPrompt ?? '').trim()}',
      AiStudyAction.createAnnotation => _annotationTask(request),
      AiStudyAction.generateFlashcards =>
        'Task: Generate exactly ${request.flashcardCount.clamp(1, 20)} flashcards from the selected study material.\n'
            'Requirements:\n'
            '- Base cards only on the selected content and surrounding context.\n'
            '- Avoid duplicate or near-duplicate cards.\n'
            '- Front = clear concise question/prompt.\n'
            '- Back = concise accurate answer (markdown ok).\n'
            '- Preserve source page when useful.\n'
            'Return JSON only matching the schema.',
      AiStudyAction.generateQuestions => _questionsTask(request),
    };
  }

  static String _rephraseTask(AiStudyRequest request) {
    final mode = request.rephraseMode ?? AiRephraseMode.clearer;
    final modeHint = switch (mode) {
      AiRephraseMode.clearer => 'Make it clearer.',
      AiRephraseMode.simpler => 'Make it simpler.',
      AiRephraseMode.moreAcademic => 'Make it more academic.',
      AiRephraseMode.shorter => 'Make it shorter.',
      AiRephraseMode.moreConcise => 'Make it more concise.',
      AiRephraseMode.fixGrammar => 'Fix grammar only.',
      AiRephraseMode.preserveMeaning =>
        'Rephrase while strictly preserving meaning.',
    };
    return 'Task: Rephrase.\n'
        'Mode: $modeHint\n'
        'Return markdown only with the rephrased text.';
  }

  static String _organizeTask(AiStudyRequest request) {
    final mode = request.organizeMode ?? AiOrganizeMode.turnIntoStudyNotes;
    final modeHint = switch (mode) {
      AiOrganizeMode.cleanFormatting => 'Clean up formatting only.',
      AiOrganizeMode.addHeadings => 'Add clear headings.',
      AiOrganizeMode.convertToBullets =>
        'Convert into bullet lists where helpful.',
      AiOrganizeMode.turnIntoStudyNotes => 'Turn into structured study notes.',
      AiOrganizeMode.organizeAcademically => 'Organize academically.',
      AiOrganizeMode.examReady => 'Create an exam-ready structure.',
    };
    return 'Task: Organize the note.\n'
        'Mode: $modeHint\n'
        'Clean structure, add headings/lists as needed. Do NOT invent lots of new academic content.\n'
        'Return markdown with # / ## / ### headings, bullets, and emphasis where helpful.';
  }

  static String _summarizeTask(AiStudyRequest request) {
    final mode = request.summarizeMode ?? AiSummarizeMode.keyPoints;
    final modeHint = switch (mode) {
      AiSummarizeMode.veryShort => 'Very short summary (2–3 sentences).',
      AiSummarizeMode.oneParagraph => 'One paragraph.',
      AiSummarizeMode.bulletPoints => 'Bullet points.',
      AiSummarizeMode.keyPoints => 'Key points.',
      AiSummarizeMode.examSummary => 'Exam-oriented summary.',
    };
    return 'Task: Summarize only the important ideas from the selected material.\n'
        'Mode: $modeHint\n'
        'Return markdown only.';
  }

  static String _translateTask(AiStudyRequest request) {
    final target = request.translateTarget ?? request.language;
    final targetHint = switch (target) {
      AiLanguage.english => 'Translate into clear English.',
      AiLanguage.persianDari =>
        'Translate into Persian/Dari. Keep English technical terms, formulas, '
            'code, variable names, and numbers unchanged.',
      AiLanguage.auto =>
        'Translate into the other natural language of the source '
            '(English ↔ Persian/Dari). Preserve technical English terms.',
    };
    return 'Task: Translate while preserving technical terminology, meaning, '
        'formulas, variable names, code, and numbers.\n'
        '$targetHint\n'
        'Return markdown only with the translation.';
  }

  static String _annotationTask(AiStudyRequest request) {
    final cats = request.categoryNames.isEmpty
        ? 'Definition, Important, Formula, Question, Example, Exam, Confusing'
        : request.categoryNames.join(', ');
    return 'Task: Draft a Study Pin annotation for the selected PDF text.\n'
        'Return JSON only matching the schema.\n'
        'suggestedCategory must be one of: $cats (or null).\n'
        'fullNote should be helpful study notes in markdown.';
  }

  static String _questionsTask(AiStudyRequest request) {
    final type = request.questionType ?? AiQuestionType.mixed;
    final count = request.questionCount.clamp(1, 50);
    final typeHint = switch (type) {
      AiQuestionType.mcq =>
        'All questions must be MCQ (type "mcq") with exactly 4 options and correctAnswer as the 0-based index of the correct option (0-3). Do not use letters or option text for correctAnswer.',
      AiQuestionType.trueFalse =>
        'All questions must be True/False (type "true_false") with boolean correctAnswer.',
      AiQuestionType.shortAnswer =>
        'All questions must be short answer (type "short_answer") with a concise string correctAnswer.',
      AiQuestionType.fillBlank =>
        'All questions must be fill-in-the-blank (type "fill_blank") with the missing value as string correctAnswer.',
      AiQuestionType.mixed =>
        'Produce a sensible mix of mcq, true_false, short_answer, and fill_blank. Total must equal $count.',
    };
    final difficultyHint = switch (request.questionDifficulty) {
      AiQuestionDifficulty.easy => 'All questions difficulty "easy".',
      AiQuestionDifficulty.medium => 'All questions difficulty "medium".',
      AiQuestionDifficulty.hard => 'All questions difficulty "hard".',
      AiQuestionDifficulty.mixed =>
        'Vary difficulty across easy, medium, and hard.',
    };

    return 'You are an educational assessment generator.\n\n'
        'Generate questions using ONLY the supplied educational material.\n\n'
        'Requirements:\n'
        '- Generate exactly $count questions.\n'
        '- Every question must be answerable from the supplied source.\n'
        '- Do not invent facts outside the supplied source.\n'
        '- Avoid duplicate or near-duplicate questions.\n'
        '- Test understanding, not only memorization.\n'
        '- MCQ must have exactly 4 options.\n'
        '- MCQ must have exactly one correct option.\n'
        '- MCQ correctAnswer must be the 0-based index (0, 1, 2, or 3).\n'
        '- Distractors should be plausible.\n'
        '- True/False must contain a boolean correct answer.\n'
        '- Short-answer questions must include a concise expected answer.\n'
        '- Fill-in-the-blank questions must include the expected missing value/text.\n'
        '- Every question must contain a short explanation.\n'
        '- Preserve the source page number when available (see "--- Page N ---" markers or PAGE:).\n'
        '- Return JSON only.\n'
        '- Do not return markdown.\n\n'
        'Question type instruction: $typeHint\n'
        'Difficulty instruction: $difficultyHint\n'
        'Return JSON matching the schema with title + questions.';
  }

  static String explainText(AiStudyRequest request) => forRequest(request);

  static String simplifyText(AiStudyRequest request) => forRequest(request);

  static String rephraseText(AiStudyRequest request) => forRequest(request);

  static String fixGrammar(AiStudyRequest request) => forRequest(request);

  static String organizeNote(AiStudyRequest request) => forRequest(request);

  static String summarizeText(AiStudyRequest request) => forRequest(request);

  static String defineText(AiStudyRequest request) => forRequest(request);

  static String giveExample(AiStudyRequest request) => forRequest(request);

  static String keyConcepts(AiStudyRequest request) => forRequest(request);

  static String examPoints(AiStudyRequest request) => forRequest(request);

  static String translateText(AiStudyRequest request) => forRequest(request);

  static String askAboutSelection(AiStudyRequest request) =>
      forRequest(request);

  static String customPrompt(AiStudyRequest request) => forRequest(request);

  static String buildAnnotationDraft(AiStudyRequest request) =>
      forRequest(request);

  static String buildFlashcards(AiStudyRequest request) => forRequest(request);

  static String buildQuestions(AiStudyRequest request) => forRequest(request);

  static String forRequest(AiStudyRequest request) {
    return '${systemPreamble(language: preambleLanguage(request), userPreference: request.userPreference)}\n'
        '${userContentForRequest(request)}';
  }

  static AiLanguage preambleLanguage(AiStudyRequest request) {
    if (request.action != AiStudyAction.translate) return request.language;
    final target = request.translateTarget ?? request.language;
    return target == AiLanguage.auto ? request.language : target;
  }
}
