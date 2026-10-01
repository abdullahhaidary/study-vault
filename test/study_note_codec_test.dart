import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:study_vault/features/study_pins/domain/study_note_codec.dart';

void main() {
  group('StudyNoteCodec', () {
    test('null and empty decode to empty documents', () {
      expect(StudyNoteCodec.decode(null).toPlainText().trim(), isEmpty);
      expect(StudyNoteCodec.decode('').toPlainText().trim(), isEmpty);
      expect(StudyNoteCodec.encodeOrNull(Document()), isNull);
      expect(StudyNoteCodec.hasContent(null), isFalse);
      expect(StudyNoteCodec.hasContent(''), isFalse);
      expect(StudyNoteCodec.hasContent('   '), isFalse);
    });

    test('legacy plain text decodes correctly', () {
      const legacy = 'Gradient descent is an optimization algorithm.';
      final doc = StudyNoteCodec.decode(legacy);

      expect(StudyNoteCodec.isRichDeltaJson(legacy), isFalse);
      expect(doc.toPlainText(), contains(legacy));
      expect(
        StudyNoteCodec.plainTextPreview(legacy),
        'Gradient descent is an optimization algorithm.',
      );
    });

    test(
      'rich delta serializes and deserializes without losing formatting',
      () {
        final original = Document.fromJson([
          {
            'insert': 'Gradient Descent\n',
            'attributes': {'header': 1},
          },
          {
            'insert': 'Important',
            'attributes': {'bold': true},
          },
          {'insert': ' term and '},
          {
            'insert': 'emphasis',
            'attributes': {'italic': true},
          },
          {'insert': '\n'},
          {
            'insert': 'Move opposite to gradient\n',
            'attributes': {'list': 'bullet'},
          },
          {
            'insert': 'Repeat until convergence\n',
            'attributes': {'list': 'ordered'},
          },
        ]);

        final encoded = StudyNoteCodec.encode(original);
        expect(StudyNoteCodec.isRichDeltaJson(encoded), isTrue);

        final roundTrip = StudyNoteCodec.decode(encoded);
        expect(roundTrip.toDelta().toJson(), original.toDelta().toJson());
        expect(roundTrip.toPlainText(), contains('Gradient Descent'));
        expect(roundTrip.toPlainText(), contains('Important'));
      },
    );

    test('plainTextPreview collapses whitespace and truncates', () {
      final encoded = StudyNoteCodec.encode(
        Document.fromJson([
          {'insert': 'Gradient Descent\n'},
          {'insert': 'An optimization algorithm that:\n'},
          {
            'insert': 'reduces cost\n',
            'attributes': {'list': 'bullet'},
          },
          {
            'insert': 'updates θ repeatedly\n',
            'attributes': {'list': 'bullet'},
          },
        ]),
      );

      final preview = StudyNoteCodec.plainTextPreview(encoded);
      expect(preview, contains('Gradient Descent'));
      expect(preview, contains('optimization'));
      expect(preview.contains('\n'), isFalse);

      final short = StudyNoteCodec.plainTextPreview(encoded, maxLength: 24);
      expect(short.endsWith('…'), isTrue);
      expect(short.length, lessThanOrEqualTo(24));
    });

    test('saving an edited legacy note stores rich delta JSON', () {
      const legacy = 'Learning rate scales each update.';
      final doc = StudyNoteCodec.decode(legacy);
      // Simulate a light edit (append space is enough to keep content).
      doc.insert(doc.length - 1, ' Keep this.');

      final stored = StudyNoteCodec.encodeOrNull(doc);
      expect(stored, isNotNull);
      expect(StudyNoteCodec.isRichDeltaJson(stored), isTrue);
      expect(jsonDecode(stored!), isA<List>());
      expect(
        StudyNoteCodec.plainTextPreview(stored),
        contains('Learning rate scales each update.'),
      );
    });

    test('malformed JSON-looking text falls back to plain text', () {
      const weird = '[not valid json for notes';
      expect(StudyNoteCodec.isRichDeltaJson(weird), isFalse);
      final doc = StudyNoteCodec.decode(weird);
      expect(doc.toPlainText(), contains(weird));
    });
  });
}
