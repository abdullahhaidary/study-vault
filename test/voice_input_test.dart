import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/voice_dictation_merge.dart';
import 'package:study_vault/features/ai_assistant/services/voice_input_service.dart';

void main() {
  group('VoiceDictationMerge', () {
    test('appends spoken text to existing with a space', () {
      expect(
        VoiceDictationMerge.join(
          before: 'Explain SHA-256',
          spoken: 'with an example',
          after: '',
        ),
        'Explain SHA-256 with an example',
      );
    });

    test('inserts at cursor without wiping prefix/suffix', () {
      expect(
        VoiceDictationMerge.join(
          before: 'Explain ',
          spoken: 'gradient descent',
          after: ' briefly',
        ),
        'Explain gradient descent briefly',
      );
    });

    test('does not add space before punctuation', () {
      expect(
        VoiceDictationMerge.join(before: 'Hello', spoken: ',', after: ' world'),
        'Hello, world',
      );
    });

    test('empty spoken returns original sandwich', () {
      expect(
        VoiceDictationMerge.join(before: 'A', spoken: '  ', after: 'B'),
        'AB',
      );
    });
  });

  group('VoiceDictationSession', () {
    test('partial results replace the speech segment only', () {
      final session = VoiceDictationSession.capture(
        text: 'Explain SHA-256',
        cursorOffset: 'Explain SHA-256'.length,
      );

      session.updateSpoken('hello');
      expect(session.composed, 'Explain SHA-256 hello');

      session.updateSpoken('hello how');
      expect(session.composed, 'Explain SHA-256 hello how');

      session.updateSpoken('hello how are');
      expect(session.composed, 'Explain SHA-256 hello how are');
    });

    test('does not duplicate partial growth', () {
      final session = VoiceDictationSession.capture(text: '', cursorOffset: 0);
      session.updateSpoken('what');
      session.updateSpoken('what is');
      session.updateSpoken('what is gradient');
      session.updateSpoken('what is gradient descent');
      expect(session.composed, 'what is gradient descent');
    });

    test('caret tracks end of spoken segment', () {
      final session = VoiceDictationSession.capture(
        text: 'Hi ',
        cursorOffset: 3,
      );
      session.updateSpoken('there');
      expect(session.caretOffset, 'Hi there'.length);
      expect(session.composed.substring(session.caretOffset), '');
    });
  });

  group('VoiceInputService locale resolution', () {
    test('prefers English locale when available', () {
      final service = VoiceInputService();
      // ignore: invalid_use_of_visible_for_testing_member
      service.debugSetLocales([
        LocaleName('fa_IR', 'Persian'),
        LocaleName('en_US', 'English (US)'),
      ]);
      expect(service.resolveLocaleId(AiLanguage.english), 'en_US');
    });

    test('prefers Persian/Dari when available', () {
      final service = VoiceInputService();
      // ignore: invalid_use_of_visible_for_testing_member
      service.debugSetLocales([
        LocaleName('en_GB', 'English (UK)'),
        LocaleName('fa_AF', 'Dari'),
      ]);
      expect(service.resolveLocaleId(AiLanguage.persianDari), 'fa_AF');
    });

    test('auto returns null for system default', () {
      final service = VoiceInputService();
      // ignore: invalid_use_of_visible_for_testing_member
      service.debugSetLocales([LocaleName('en_US', 'English')]);
      expect(service.resolveLocaleId(AiLanguage.auto), isNull);
    });
  });
}
