import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_translation.dart';

void main() {
  test('segments split on blank lines after the target and never in code', () {
    final big = 'word ' * 800;
    final content =
        '# One\n$big\n\n```dart\n${'code\n' * 900}\n\nmore\n```\n\n# Two\nend';
    final segments = PdfAiTranslation.segments(content);
    expect(segments.length, greaterThan(1));
    expect(segments.join(), '$content\n');
    for (final segment in segments) {
      expect('```'.allMatches(segment).length.isEven, isTrue);
    }
  });

  test('stored translations keep segment boundaries', () {
    const parts = ['# الف\nمتن\n', '## ب\nادامه'];
    final stored = PdfAiTranslation.join(parts);
    expect(PdfAiTranslation.split(stored), ['# الف\nمتن\n', '## ب\nادامه\n']);
    expect(PdfAiTranslation.plain(stored), '# الف\nمتن\n## ب\nادامه\n');
    expect(PdfAiTranslation.split('no markers'), ['no markers']);
  });

  test('code, formulas, charts and slide markers are protected', () {
    const segment =
        '# Title\nUse `x`.\n```python\nprint("hi")\n```\n\$\$\na^2+b^2\n\$\$\n'
        '<!-- slide -->\n~~~chart\n{"type":"bar"}\n~~~\nEnd';
    final protected = PdfAiTranslation.protect(segment);
    expect(protected.blocks, hasLength(4));
    expect(protected.text, isNot(contains('print')));
    expect(protected.text, isNot(contains('a^2')));
    expect(protected.text, contains('Use `x`.'));

    final translated = protected.text
        .replaceAll('# Title', '# عنوان')
        .replaceAll('End', 'پایان');
    final restored = protected.restore(translated);
    expect(restored, contains('print("hi")'));
    expect(restored, contains('<!-- slide -->'));
    expect(restored, contains('# عنوان'));

    expect(
      () => protected.restore(translated.replaceFirst('⟦SV1⟧', '')),
      throwsFormatException,
    );
    expect(() => protected.restore('$translated ⟦SV9⟧'), throwsFormatException);
  });

  test('heading count ignores headings inside code', () {
    expect(PdfAiTranslation.headingCount('# A\n```\n# not\n```\n## B'), 2);
  });

  test('prompt keeps structure rules and placeholders', () {
    final prompt = PdfAiTranslation.messages('⟦SV0⟧\n# Title').last['content']!;
    expect(prompt, contains('Persian'));
    expect(prompt, contains('⟦SV0⟧'));
    expect(prompt, contains('same headings'));
    expect(
      PdfAiTranslation.messages('x', strict: true).last['content'],
      contains('previous answer changed the structure'),
    );
  });
}
