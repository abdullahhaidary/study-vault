import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_chat/services/chat_speech_service.dart';

void main() {
  group('chatSpeechPlainText', () {
    test('strips light markdown syntax', () {
      expect(
        chatSpeechPlainText('See [docs](https://example.com) and `code` **bold**'),
        'See docs and code bold',
      );
    });
  });

  group('chatSpeechChunks', () {
    test('keeps short text as one chunk', () {
      expect(chatSpeechChunks('Hello world.', maxChars: 100), ['Hello world.']);
    });

    test('splits long text under the limit', () {
      final sentence = 'This is a full sentence about mutations and caching. ';
      final text = sentence * 80;
      final chunks = chatSpeechChunks(text, maxChars: 400);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= 400), isTrue);
      expect(chunks.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
          text.replaceAll(RegExp(r'\s+'), ' ').trim());
    });

    test('prefers paragraph boundaries', () {
      final a = 'A' * 50;
      final b = 'B' * 50;
      final chunks = chatSpeechChunks('$a\n\n$b', maxChars: 60);
      expect(chunks, [a, b]);
    });
  });
}
