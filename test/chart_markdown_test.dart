import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_vault/core/markdown/chart_block.dart';
import 'package:study_vault/core/markdown/chart_markdown_builder.dart';
import 'package:study_vault/core/markdown/chart_spec.dart';

const _bar =
    '{"type":"bar","title":"Scores","labels":["L1","L2","L3"],'
    '"series":[{"name":"Score","data":[72,85,90]}],"yLabel":"%"}';

Widget _markdown(String data) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final style = MarkdownStyleSheet.fromTheme(Theme.of(context));
          return SingleChildScrollView(
            child: MarkdownBody(
              data: data,
              styleSheet: style,
              builders: chartMarkdownBuilders(style),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  group('ChartSpec.tryParse', () {
    test('parses bar spec with series', () {
      final spec = ChartSpec.tryParse(_bar)!;
      expect(spec.kind, ChartKind.bar);
      expect(spec.title, 'Scores');
      expect(spec.labels, ['L1', 'L2', 'L3']);
      expect(spec.series.single.name, 'Score');
      expect(spec.series.single.data, [72, 85, 90]);
      expect(spec.yLabel, '%');
      expect(spec.maxValue, 90);
    });

    test('accepts shorthand data and aliases', () {
      final spec = ChartSpec.tryParse(
        '{"type":"Donut","labels":["a","b"],"data":["1.5",2]}',
      )!;
      expect(spec.kind, ChartKind.pie);
      expect(spec.series.single.data, [1.5, 2]);
    });

    test('rejects malformed input', () {
      expect(ChartSpec.tryParse('not json'), isNull);
      expect(ChartSpec.tryParse('[1,2]'), isNull);
      expect(ChartSpec.tryParse('{"type":"radar","labels":["a"]}'), isNull);
      // Series length must match labels.
      expect(
        ChartSpec.tryParse(
          '{"type":"line","labels":["a","b"],"series":[{"data":[1]}]}',
        ),
        isNull,
      );
      // Pie needs exactly one series.
      expect(
        ChartSpec.tryParse(
          '{"type":"pie","labels":["a"],"series":[{"data":[1]},{"data":[2]}]}',
        ),
        isNull,
      );
      expect(
        ChartSpec.tryParse('{"type":"bar","labels":["a"],"data":["x"]}'),
        isNull,
      );
    });
  });

  group('chart markdown builder', () {
    testWidgets('renders ```chart blocks as charts', (tester) async {
      await tester.pumpWidget(_markdown('Intro\n\n```chart\n$_bar\n```\n'));
      expect(find.byType(ChartBlock), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Scores'), findsOneWidget);
      expect(find.text('Intro'), findsOneWidget);
    });

    testWidgets('renders line and pie kinds', (tester) async {
      await tester.pumpWidget(
        _markdown(
          '```chart\n{"type":"line","labels":["a","b"],"data":[1,2]}\n```\n\n'
          '```chart\n{"type":"pie","labels":["a","b"],"data":[1,2]}\n```\n',
        ),
      );
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('falls back to a code block for invalid chart JSON', (
      tester,
    ) async {
      await tester.pumpWidget(_markdown('```chart\n{oops\n```\n'));
      expect(find.byType(ChartBlock), findsNothing);
      expect(find.text('{oops'), findsOneWidget);
    });

    testWidgets('leaves ordinary code blocks untouched', (tester) async {
      await tester.pumpWidget(_markdown('```dart\nvoid main() {}\n```\n'));
      expect(find.byType(ChartBlock), findsNothing);
      expect(find.text('void main() {}'), findsOneWidget);
    });
  });
}
