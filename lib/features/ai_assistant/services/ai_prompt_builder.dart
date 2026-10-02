import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';

/// Builds study-action prompts (provider-agnostic single source of truth).
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
    if (request.pageNumber != null) {
      buffer.writeln('PAGE: ${request.pageNumber}');
      buffer.writeln();
    }
    buffer.writeln('SELECTED TEXT:');
    buffer.writeln(selected);
    final surrounding = request.surroundingText?.trim();
    if (surrounding != null && surrounding.isNotEmpty) {
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

  static String explainText(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Explain the selected text clearly for a university student.\n'
        'Requirements:\n'
        '- explain the meaning\n'
        '- explain difficult terminology\n'
        '- explain why it matters\n'
        '- use a simple example when helpful\n'
        '- do not introduce unrelated concepts\n'
        'Return markdown only (no JSON).\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String simplifyText(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Rewrite/explain the selected material in simpler language '
        'without changing its meaning.\n'
        'Keep technical terms and formulas. Return markdown only.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String rephraseText(AiStudyRequest request) {
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
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Rephrase.\n'
        'Mode: $modeHint\n'
        'Return markdown only with the rephrased text.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String fixGrammar(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Fix grammar and wording while preserving meaning and technical terms.\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}';
  }

  static String organizeNote(AiStudyRequest request) {
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
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Organize the note.\n'
        'Mode: $modeHint\n'
        'Clean structure, add headings/lists as needed. Do NOT invent lots of new academic content.\n'
        'Return markdown with # / ## / ### headings, bullets, and emphasis where helpful.\n\n'
        'NOTE:\n${request.sourceText}'
        '${_conversationBlock(request)}';
  }

  static String summarizeText(AiStudyRequest request) {
    final mode = request.summarizeMode ?? AiSummarizeMode.keyPoints;
    final modeHint = switch (mode) {
      AiSummarizeMode.veryShort => 'Very short summary (2–3 sentences).',
      AiSummarizeMode.oneParagraph => 'One paragraph.',
      AiSummarizeMode.bulletPoints => 'Bullet points.',
      AiSummarizeMode.keyPoints => 'Key points.',
      AiSummarizeMode.examSummary => 'Exam-oriented summary.',
    };
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Summarize only the important ideas from the selected material.\n'
        'Mode: $modeHint\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String defineText(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Identify the main concept or term in the selected text and provide:\n'
        '- definition\n'
        '- meaning in this context\n'
        '- short example\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String giveExample(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Provide one or two examples that directly demonstrate the selected concept.\n'
        'Keep examples concrete and tied to the source. Return markdown only.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String keyConcepts(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Extract the most important key concepts / terms from the source.\n'
        'Requirements:\n'
        '- Return a short markdown list (prefer 3–8 items).\n'
        '- Each item: **Term** — concise definition grounded in the source.\n'
        '- Preserve formulas, variable names, and technical English terms.\n'
        '- Do not invent concepts not supported by the source.\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String examPoints(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Help the student prepare for exams based ONLY on this source.\n'
        'Return concise markdown with these sections when useful:\n'
        '- Important definition / concept\n'
        '- Common confusion\n'
        '- One short exam-style practice question (do NOT claim this predicts a real exam)\n'
        'Stay grounded in the source. Preserve formulas and technical terms.\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String translateText(AiStudyRequest request) {
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
    return '${systemPreamble(language: target == AiLanguage.auto ? request.language : target, userPreference: request.userPreference)}\n'
        'Task: Translate while preserving technical terminology, meaning, '
        'formulas, variable names, code, and numbers.\n'
        '$targetHint\n'
        'Return markdown only with the translation.\n\n'
        '${materialBlock(request)}'
        '${_conversationBlock(request)}';
  }

  static String askAboutSelection(AiStudyRequest request) {
    final question = (request.customPrompt ?? '').trim();
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Answer the student question about the selected study material.\n'
        'Base the answer on the selected text and surrounding context only.\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}\n\n'
        'STUDENT QUESTION:\n$question'
        '${_conversationBlock(request)}';
  }

  static String customPrompt(AiStudyRequest request) {
    final instruction = (request.customPrompt ?? '').trim();
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Follow the student custom instruction for the selected material.\n'
        'Stay grounded in the selected text and surrounding context.\n'
        'Return markdown only.\n\n'
        '${materialBlock(request)}\n\n'
        'CUSTOM INSTRUCTION:\n$instruction'
        '${_conversationBlock(request)}';
  }

  static String buildAnnotationDraft(AiStudyRequest request) {
    final cats = request.categoryNames.isEmpty
        ? 'Definition, Important, Formula, Question, Example, Exam, Confusing'
        : request.categoryNames.join(', ');
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Draft a Study Pin annotation for the selected PDF text.\n'
        'Return JSON only matching the schema.\n'
        'suggestedCategory must be one of: $cats (or null).\n'
        'fullNote should be helpful study notes in markdown.\n\n'
        '${materialBlock(request)}';
  }

  static String buildFlashcards(AiStudyRequest request) {
    final n = request.flashcardCount.clamp(1, 20);
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Generate exactly $n flashcards from the selected study material.\n'
        'Requirements:\n'
        '- Base cards only on the selected content and surrounding context.\n'
        '- Avoid duplicate or near-duplicate cards.\n'
        '- Front = clear concise question/prompt.\n'
        '- Back = concise accurate answer (markdown ok).\n'
        '- Preserve source page when useful.\n'
        'Return JSON only matching the schema.\n\n'
        '${materialBlock(request)}';
  }

  static String buildQuestions(AiStudyRequest request) {
    final type = request.questionType ?? AiQuestionType.mixed;
    final difficulty = request.questionDifficulty;
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
    final difficultyHint = switch (difficulty) {
      AiQuestionDifficulty.easy => 'All questions difficulty "easy".',
      AiQuestionDifficulty.medium => 'All questions difficulty "medium".',
      AiQuestionDifficulty.hard => 'All questions difficulty "hard".',
      AiQuestionDifficulty.mixed =>
        'Vary difficulty across easy, medium, and hard.',
    };

    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'You are an educational assessment generator.\n\n'
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
        'Return JSON matching the schema with title + questions.\n\n'
        'SOURCE MATERIAL:\n${request.sourceText}';
  }

  static String forRequest(AiStudyRequest request) {
    return switch (request.action) {
      AiStudyAction.explain => explainText(request),
      AiStudyAction.simplify => simplifyText(request),
      AiStudyAction.rephrase => rephraseText(request),
      AiStudyAction.fixGrammar => fixGrammar(request),
      AiStudyAction.organize => organizeNote(request),
      AiStudyAction.summarize => summarizeText(request),
      AiStudyAction.define => defineText(request),
      AiStudyAction.giveExample => giveExample(request),
      AiStudyAction.translate => translateText(request),
      AiStudyAction.askAi => askAboutSelection(request),
      AiStudyAction.customPrompt => customPrompt(request),
      AiStudyAction.createAnnotation => buildAnnotationDraft(request),
      AiStudyAction.generateFlashcards => buildFlashcards(request),
      AiStudyAction.generateQuestions => buildQuestions(request),
      AiStudyAction.keyConcepts => keyConcepts(request),
      AiStudyAction.examPoints => examPoints(request),
    };
  }
}
