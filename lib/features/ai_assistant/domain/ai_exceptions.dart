/// User-facing AI failures (never include API keys or raw prompts).
sealed class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AiNotConfiguredException extends AiException {
  const AiNotConfiguredException([
    super.message = 'AI is not configured yet. Add an API key in Settings.',
  ]);
}

class AiPrivacyNotAcceptedException extends AiException {
  const AiPrivacyNotAcceptedException()
    : super('Please accept the AI privacy notice first.');
}

class AiOfflineException extends AiException {
  const AiOfflineException()
    : super('AI Assistant requires an internet connection.');
}

class AiInvalidKeyException extends AiException {
  const AiInvalidKeyException([
    super.message = 'The AI API key appears to be invalid.',
  ]);
}

class AiQuotaException extends AiException {
  const AiQuotaException([
    super.message = 'AI quota or balance exceeded. Try again later.',
  ]);
}

class AiRateLimitException extends AiException {
  const AiRateLimitException()
    : super('Too many AI requests. Please wait a moment.');
}

class AiTimeoutException extends AiException {
  const AiTimeoutException()
    : super('The AI request timed out. Please try again.');
}

class AiUnsupportedModelException extends AiException {
  const AiUnsupportedModelException([
    super.message = 'The selected AI model is not available for this API key.',
  ]);
}

class AiServerException extends AiException {
  const AiServerException([
    super.message = 'AI service error. Please try again.',
  ]);
}

class AiEmptyResultException extends AiException {
  const AiEmptyResultException([
    super.message = 'The AI returned an empty result.',
  ]);
}

class AiMalformedOutputException extends AiException {
  const AiMalformedOutputException([
    super.message = 'Could not understand the AI response. Please try again.',
  ]);
}

class AiSourceTooLargeException extends AiException {
  const AiSourceTooLargeException()
    : super(
        'This text is too large for one AI request. '
        'Select a smaller portion.',
      );
}

class AiCancelledException extends AiException {
  const AiCancelledException() : super('AI request cancelled.');
}

class AiEmptySelectionException extends AiException {
  const AiEmptySelectionException()
    : super('Select or provide text for AI first.');
}

class AiStyleMemoryTooLargeException extends AiException {
  AiStyleMemoryTooLargeException({required this.tokens, required this.budget})
    : super(
        'Hidden AI style notes are $tokens tokens (limit $budget). '
        'Edit or delete notes in Settings → AI before sending.',
      );

  AiStyleMemoryTooLargeException.itemTooLong(int maxChars)
    : tokens = 0,
      budget = 0,
      super(
        'Each style note must be $maxChars characters or fewer. '
        'Split it into shorter notes.',
      );

  final int tokens;
  final int budget;
}
