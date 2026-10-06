import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/markdown/notation_block.dart';
import 'package:study_vault/core/markdown/notation_spec.dart';
import 'package:study_vault/core/markdown/study_markdown.dart';

const _mapping = '''
[Business Process / Needs] ---> Arguments, unaligned perspectives
[Software / Implementation] ---> The built house
[UML (Unified Modeling Language)] ---> The architectural floor plan (visual coordination)
''';

const _tree = '''
                    UML
        "A shared visual language"
                    |
        ........................
        |                      |
    STRUCTURE              BEHAVIOR
    (The Building)         (Life Inside)
    A Photograph           A Film
''';

Widget _markdown(String data) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final style = MarkdownStyleSheet.fromTheme(Theme.of(context));
          return SingleChildScrollView(
            child: StudyMarkdown(data: data, styleSheet: style),
          );
        },
      ),
    ),
  );
}

void main() {
  group('NotationSpec.tryParse', () {
    test('parses bracketed arrow mappings', () {
      final spec = NotationSpec.tryParse(_mapping);
      expect(spec, isA<MappingNotation>());
      final mapping = spec! as MappingNotation;
      expect(mapping.pairs, hasLength(3));
      expect(mapping.pairs.first.from, 'Business Process / Needs');
      expect(mapping.pairs.first.to, 'Arguments, unaligned perspectives');
      expect(mapping.pairs.last.from, 'UML (Unified Modeling Language)');
    });

    test('parses a two-branch ASCII tree', () {
      final spec = NotationSpec.tryParse(_tree);
      expect(spec, isA<TreeNotation>());
      final tree = spec! as TreeNotation;
      expect(tree.root, 'UML');
      expect(tree.subtitle, 'A shared visual language');
      expect(tree.branches, hasLength(2));
      expect(tree.branches[0].title, 'STRUCTURE');
      expect(tree.branches[0].details, ['(The Building)', 'A Photograph']);
      expect(tree.branches[1].title, 'BEHAVIOR');
      expect(tree.branches[1].details, ['(Life Inside)', 'A Film']);
    });

    test('parses a UML class box', () {
      const source = '''
+----------------------------------+
|            Student               |  <-- Compartment 1: Name (Concept)
+----------------------------------+
| id : String                      |  <-- Compartment 2: Attributes
| name : String                    |
+----------------------------------+
| register()                       |  <-- Compartment 3: Operations
| dropCourse()                     |
+----------------------------------+
''';
      final spec = NotationSpec.tryParse(source);
      expect(spec, isA<ClassBoxNotation>());
      final box = spec! as ClassBoxNotation;
      expect(box.className, 'Student');
      expect(box.compartments, hasLength(2));
      expect(box.compartments[0].lines, ['id : String', 'name : String']);
      expect(box.compartments[1].lines, ['register()', 'dropCourse()']);
    });

    test('parses UML relationship and multiplicity lines', () {
      const source = '''
Association:     Class A --------------- Class B
Generalization:  Child  ---------------|> Parent
Aggregation:     Whole  <>-------------- Part
Composition:     Whole  ♦--------------- Part
Student [1] ----------- [0..*] Enrollment: A student can have many enrollments.
''';
      final spec = NotationSpec.tryParse(source);
      expect(spec, isA<RelationshipNotation>());
      final rel = spec! as RelationshipNotation;
      expect(rel.items, hasLength(5));
      expect(rel.items[0].kind, UmlConnectorKind.association);
      expect(rel.items[1].kind, UmlConnectorKind.generalization);
      expect(rel.items[2].kind, UmlConnectorKind.aggregation);
      expect(rel.items[3].kind, UmlConnectorKind.composition);
      expect(rel.items[4].left, 'Student');
      expect(rel.items[4].leftMultiplicity, '1');
      expect(rel.items[4].rightMultiplicity, '0..*');
      expect(rel.items[4].right, 'Enrollment');
    });

    test('parses a vertical stack of bracketed diagrams', () {
      const source = '''
BEHAVIORAL PERSPECTIVES (The Four "Films")

[ Use Case Diagram ]
Goal & Value: "What external result is desired?"
    |
    v
[ Activity Diagram ]
Process Flow: "What sequence of work steps occur?"
''';
      final spec = NotationSpec.tryParse(source);
      expect(spec, isA<StackFlowNotation>());
      final stack = spec! as StackFlowNotation;
      expect(stack.title, contains('BEHAVIORAL PERSPECTIVES'));
      expect(stack.items, hasLength(2));
      expect(stack.items[0].title, 'Use Case Diagram');
      expect(stack.items[1].title, 'Activity Diagram');
    });

    test('parses a boxed pipeline with side labels', () {
      const source = '''
Logical / Ideas     +-----------------+     Book, Member, Loan
                    | Class Diagram   |
                    +--------+--------+
                            |
                            v
Software Packaging  +-----------------+     CatalogService
                    | Component Diagram |
                    +--------+--------+
''';
      final spec = NotationSpec.tryParse(source);
      expect(spec, isA<PipelineNotation>());
      final pipe = spec! as PipelineNotation;
      expect(pipe.steps, hasLength(2));
      expect(pipe.steps[0].title, 'Class Diagram');
      expect(pipe.steps[0].left, 'Logical / Ideas');
      expect(pipe.steps[0].right, 'Book, Member, Loan');
      expect(pipe.steps[1].title, 'Component Diagram');
    });

    test('parses a comparison ASCII table', () {
      const source = '''
THE TWO PILLARS
| STRUCTURAL MODELING | BEHAVIORAL MODELING |
| The Photograph | The Film |
| Class Diagram | Use Case Diagram |
''';
      final spec = NotationSpec.tryParse(source);
      expect(spec, isA<TableNotation>());
      final table = spec! as TableNotation;
      expect(table.caption, 'THE TWO PILLARS');
      expect(table.headers, ['STRUCTURAL MODELING', 'BEHAVIORAL MODELING']);
      expect(table.rows, hasLength(2));
    });

    test('parses a simple mermaid graph as mappings', () {
      final spec = NotationSpec.tryParse(
        'graph TD\n'
        'A[Business Process] --> B[Unaligned perspectives]\n'
        'C[Software] --> D[Built house]\n',
        language: 'mermaid',
      );
      expect(spec, isA<MappingNotation>());
      final mapping = spec! as MappingNotation;
      expect(mapping.pairs.first.from, 'Business Process');
      expect(mapping.pairs.first.to, 'Unaligned perspectives');
    });

    test('does not swallow programming code', () {
      expect(NotationSpec.tryParse('void main() {}', language: 'dart'), isNull);
      expect(NotationSpec.tryParse('just a sentence'), isNull);
    });
  });

  group('notation markdown builder', () {
    testWidgets('renders mapping ASCII as professional cards', (tester) async {
      await tester.pumpWidget(_markdown('```\n$_mapping\n```\n'));
      expect(find.byType(NotationBlock), findsOneWidget);
      expect(find.text('Business Process / Needs'), findsOneWidget);
      expect(find.text('The built house'), findsOneWidget);
      expect(find.textContaining('--->'), findsNothing);
    });

    testWidgets('renders ASCII trees as a root and branches', (tester) async {
      await tester.pumpWidget(_markdown('```text\n$_tree\n```\n'));
      expect(find.byType(NotationBlock), findsOneWidget);
      expect(find.text('UML'), findsOneWidget);
      expect(find.text('A shared visual language'), findsOneWidget);
      expect(find.text('STRUCTURE'), findsOneWidget);
      expect(find.textContaining('(Life Inside)'), findsOneWidget);
    });

    testWidgets('renders a UML class box from a fenced diagram', (
      tester,
    ) async {
      await tester.pumpWidget(
        _markdown('''
```
+------------------+
|     Student      |
+------------------+
| id : String      |
+------------------+
| register()       |
+------------------+
```
'''),
      );
      expect(find.byType(NotationBlock), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('id : String'), findsOneWidget);
      expect(find.text('register()'), findsOneWidget);
    });

    testWidgets('renders unfenced multiplicity lines as diagrams', (
      tester,
    ) async {
      await tester.pumpWidget(
        _markdown(
          'Student [1] ----------- [0..*] Enrollment: Many enrollments.\n'
          'Course [1] ----------- [1..*] Teacher: At least one teacher.\n',
        ),
      );
      expect(find.byType(NotationBlock), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Enrollment'), findsOneWidget);
      expect(find.text('0..*'), findsOneWidget);
    });
  });
}
