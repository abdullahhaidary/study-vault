import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';

/// Builds Gemini prompts for study actions (single source of truth).
abstract final class AiPromptBuilder {
  static const _preserveRules = '''
Preserve-meaning rules (mandatory):
- Preserve the original meaning.
- Do not invent unsupported facts or academic claims.
- Do not remove important details.
- Preserve equations, formulas, symbols (θ, α, ∇, etc.), and code.
- Preserve technical English terms (Gradient Descent, Learning Rate, Precision, Recall, Cost Function, API, etc.) — do not translate them unless explicitly asked.
- Preserve the source language unless a language override is requested.
''';

  static String systemPreamble({
    required AiLanguage language,
    String? userPreference,
  }) {
    final lang = switch (language) {
      AiLanguage.auto =>
        'Respond mainly in the source language. For mixed Persian/Dari + English, keep the same mix and preserve English technical terms.',
      AiLanguage.english => 'Respond in English.',
      AiLanguage.persianDari =>
        'Respond in Persian/Dari, but keep English technical terms and formulas unchanged.',
    };
    final preference = (userPreference == null || userPreference.trim().isEmpty)
        ? ''
        : '\nUser study preference: ${userPreference.trim()}\n';
    return 'You are Study Vault AI Assistant for university students.\n'
        '$lang\n'
        '$_preserveRules'
        '$preference';
  }

  static String explainText(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Explain the following study text clearly at university level.\n'
        'Use short paragraphs. Preserve technical terms and formulas.\n'
        'Return markdown only (no JSON).\n\n'
        'TEXT:\n${request.sourceText}';
  }

  static String simplifyText(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Simplify difficult text.\n'
        'Keep the same meaning, simpler language, preserve technical terms, formulas, and important details.\n'
        'Return markdown only.\n\n'
        'TEXT:\n${request.sourceText}';
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
      AiRephraseMode.preserveMeaning => 'Rephrase while strictly preserving meaning.',
    };
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Rephrase.\n'
        'Mode: $modeHint\n'
        'Return markdown only with the rephrased text.\n\n'
        'TEXT:\n${request.sourceText}';
  }

  static String fixGrammar(AiStudyRequest request) {
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Fix grammar and wording while preserving meaning and technical terms.\n'
        'Return markdown only.\n\n'
        'TEXT:\n${request.sourceText}';
  }

  static String organizeNote(AiStudyRequest request) {
    final mode = request.organizeMode ?? AiOrganizeMode.turnIntoStudyNotes;
    final modeHint = switch (mode) {
      AiOrganizeMode.cleanFormatting => 'Clean up formatting only.',
      AiOrganizeMode.addHeadings => 'Add clear headings.',
      AiOrganizeMode.convertToBullets => 'Convert into bullet lists where helpful.',
      AiOrganizeMode.turnIntoStudyNotes => 'Turn into structured study notes.',
      AiOrganizeMode.organizeAcademically => 'Organize academically.',
      AiOrganizeMode.examReady => 'Create an exam-ready structure.',
    };
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Organize the note.\n'
        'Mode: $modeHint\n'
        'Clean structure, add headings/lists as needed. Do NOT invent lots of new academic content.\n'
        'Return markdown with # / ## / ### headings, bullets, and emphasis where helpful.\n\n'
        'NOTE:\n${request.sourceText}';
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
        'Task: Summarize.\n'
        'Mode: $modeHint\n'
        'Return markdown only.\n\n'
        'TEXT:\n${request.sourceText}';
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
        'SELECTED TEXT:\n${request.selectedText ?? request.sourceText}\n'
        '${request.shortDescription == null ? '' : 'EXISTING SHORT DESCRIPTION:\n${request.shortDescription}\n'}';
  }

  static String buildFlashcards(AiStudyRequest request) {
    final n = request.flashcardCount.clamp(1, 10);
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Generate exactly $n flashcards from the study text.\n'
        'Front = clear question/prompt. Back = concise accurate answer (markdown ok).\n'
        'Return JSON only matching the schema.\n\n'
        'TEXT:\n${request.sourceText}';
  }

  static String buildQuestions(AiStudyRequest request) {
    final type = request.questionType ?? AiQuestionType.conceptual;
    final typeHint = switch (type) {
      AiQuestionType.conceptual => 'Conceptual questions with short answers.',
      AiQuestionType.shortAnswer => 'Short-answer questions.',
      AiQuestionType.mixed => 'Mix of conceptual and short-answer questions.',
    };
    return '${systemPreamble(language: request.language, userPreference: request.userPreference)}\n'
        'Task: Generate 3–5 study questions.\n'
        'Type: $typeHint\n'
        'Return JSON only matching the schema.\n\n'
        'TEXT:\n${request.sourceText}';
  }

  static String forRequest(AiStudyRequest request) {
    return switch (request.action) {
      AiStudyAction.explain => explainText(request),
      AiStudyAction.simplify => simplifyText(request),
      AiStudyAction.rephrase => rephraseText(request),
      AiStudyAction.fixGrammar => fixGrammar(request),
      AiStudyAction.organize => organizeNote(request),
      AiStudyAction.summarize => summarizeText(request),
      AiStudyAction.createAnnotation => buildAnnotationDraft(request),
      AiStudyAction.generateFlashcards => buildFlashcards(request),
      AiStudyAction.generateQuestions => buildQuestions(request),
    };
  }
}
