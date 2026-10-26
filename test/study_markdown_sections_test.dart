import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/markdown/study_markdown_sections.dart';

void main() {
  test('splits on headings and keeps a fenced heading intact', () {
    const source = '''
# Title

Intro with \$n\$.

## First

One paragraph.

```
## not a heading
```

## Second

More.
''';
    final pieces = splitStudyMarkdown(source);
    expect(pieces.first, contains('# Title'));
    expect(pieces.any((piece) => piece.startsWith('## First')), isTrue);
    expect(pieces.any((piece) => piece.startsWith('## Second')), isTrue);
    final fenced = pieces.singleWhere((piece) => piece.contains('```'));
    expect(fenced, contains('## not a heading'));
    expect(fenced, isNot(startsWith('## not a heading')));
  });

  test('cuts a long answer key into pieces small enough to lay out', () {
    final buffer = StringBuffer('## Answer key\n\n');
    for (var n = 1; n <= 40; n++) {
      buffer.writeln('**$n.** \$O(n^$n)\$ and \$\\Theta(n)\$ for the bound.');
      buffer.writeln();
    }
    final pieces = splitStudyMarkdown(buffer.toString());
    expect(pieces.length, greaterThan(3));
    for (final piece in pieces) {
      expect(piece.split('\n').length, lessThan(80));
      expect('\$'.allMatches(piece).length, lessThan(120));
    }
    expect(pieces.first, contains('## Answer key'));
    expect(pieces.last, contains('**40.**'));
  });

  test('lecture 01 starts with a short piece', () {
    final source = File(
      'docs/data-structures/lesson-01-models-adts-asymptotic-analysis.md',
    ).readAsStringSync();
    final pieces = splitStudyMarkdown(source);
    expect(pieces.length, greaterThan(20));
    expect(pieces.first.split('\n').length, lessThan(40));
    expect('\$'.allMatches(pieces.first).length, lessThan(20));
  });

  test('does not cut a display equation or a table', () {
    final equation = StringBuffer('## Proof\n\n');
    equation.writeln(r'$$');
    for (var n = 0; n < 50; n++) {
      equation.writeln(r'f(n) = n');
      equation.writeln();
    }
    equation.writeln(r'$$');
    equation.writeln();
    equation.writeln('After.');
    final equationPieces = splitStudyMarkdown(equation.toString());
    expect(
      equationPieces.singleWhere((piece) => piece.contains(r'$$')),
      contains('After.'),
    );

    final table = StringBuffer('## Costs\n\n');
    table.writeln('| n | cost |');
    table.writeln('| --- | --- |');
    for (var n = 1; n <= 50; n++) {
      table.writeln('| $n | \$n^2\$ |');
    }
    final tablePieces = splitStudyMarkdown(table.toString());
    expect(tablePieces, hasLength(1));
  });
}
