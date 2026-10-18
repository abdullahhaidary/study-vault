import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/markdown/ascii_diagram_repair.dart';
import 'package:study_vault/core/markdown/bare_fence_repair.dart';
import 'package:study_vault/core/markdown/study_markdown_repair.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_versioning.dart';

void main() {
  group('BareFenceRepair', () {
    test('wraps bare jsx language tags without swallowing following prose', () {
      const broken = '''
### Objects — Incorrect

jsx
const [user, setUser] = useState({ name: "Ahmad", age: 25 });
user.name = "Ali";
setUser(user); // same reference → React may skip


### Objects — Correct

jsx
setUser(prev => ({ ...prev, name: "Ali" }));


Here, the spread copies existing fields.
''';
      final fixed = BareFenceRepair.repair(broken);
      expect(fixed, contains('```jsx\nconst [user, setUser]'));
      expect(fixed, contains('```jsx\nsetUser(prev =>'));
      expect(fixed, contains('Here, the spread copies existing fields.'));
      expect(
        fixed,
        isNot(
          contains(
            '```jsx\nsetUser(prev => ({ ...prev, name: "Ali" }));\n\n\nHere,',
          ),
        ),
      );
      expect(RegExp(r'^jsx$', multiLine: true).hasMatch(fixed), isFalse);
      expect(fixed.split('```').length - 1, 4);
    });

    test('stops a fence before prose that mentions the word function', () {
      const broken = '''
### Example

jsx
function Welcome() {
  return <h1>Welcome</h1>;
}

export default Welcome;


That's it. A function that returns markup.
''';
      final fixed = BareFenceRepair.repair(broken);
      expect(
        fixed,
        contains(
          '```jsx\n'
          'function Welcome() {\n'
          '  return <h1>Welcome</h1>;\n'
          '}\n'
          '\n'
          'export default Welcome;\n'
          '```\n'
          '\n'
          '\n'
          "That's it. A function that returns markup.",
        ),
      );
    });

    test('restores chart fences for Study Vault chart blocks', () {
      const broken = '''
Sizes:

chart
{"type":"bar","title":"Hash","labels":["MD5"],"series":[{"name":"bits","data":[128]}]}

More text.
''';
      final fixed = BareFenceRepair.repair(broken);
      expect(
        fixed,
        contains(
          '```chart\n'
          '{"type":"bar","title":"Hash","labels":["MD5"],"series":[{"name":"bits","data":[128]}]}\n'
          '```',
        ),
      );
      expect(fixed, contains('More text.'));
    });

    test('leaves already-fenced code unchanged', () {
      const ok = '''
```jsx
const x = 1;
```
''';
      expect(BareFenceRepair.repair(ok), ok);
    });
  });

  test('PdfAiManualJson repair runs on imported content', () {
    final markdown = PdfAiManualJson.extractMarkdown(
      '{"format":"study-vault-pdf-ai","type":"summary","content":"'
      '### Demo\\n\\n'
      'jsx\\n'
      'const n = 1;\\n'
      '\\n'
      'Done."}',
      PdfAiMaterialType.summary,
    );
    expect(markdown, contains('```jsx\nconst n = 1;\n```'));
    expect(markdown, contains('Done.'));
  });

  group('AsciiDiagramRepair', () {
    test('fences indented box trees so Markdown cannot split them', () {
      const broken = '''
### Visualizing Composition

        ┌─────────────┐
        │     App     │
        └──────┬──────┘
     ┌─────────┼─────────┐
     ▼         ▼         ▼
 ┌───────┐ ┌───────┐ ┌─────────┐
 │Header │ │Sidebar│ │Dashboard│
 └───────┘ └───────┘ └─────────┘

### Next
''';
      final fixed = AsciiDiagramRepair.repair(broken);
      expect(fixed, contains('```plaintext'));
      expect(fixed, contains('│Header │ │Sidebar│ │Dashboard│'));
      expect(
        fixed.indexOf('```plaintext'),
        lessThan(fixed.indexOf('│Header │')),
      );
      expect(
        fixed.indexOf('└───────┘ └───────┘ └─────────┘'),
        lessThan(fixed.indexOf('```', fixed.indexOf('│Header │'))),
      );
    });
  });

  test('StudyMarkdownRepair runs code-fence then ascii repairs', () {
    const broken = '''
jsx
const x = 1;

        ┌───┐
        │ A │
        └─┬─┘
          ▼
        ┌───┐
        │ B │
        └───┘
''';
    final fixed = StudyMarkdownRepair.repair(broken);
    expect(fixed, contains('```jsx\nconst x = 1;\n```'));
    expect(fixed, contains('```plaintext'));
    expect(fixed, contains('│ A │'));
  });

  test('StudyMarkdownRepair densifies doublespaced csharp after fencing', () {
    const broken = r'''
`csharp

public class Demo

{

    public void Run() { }

}

''';
    final fixed = StudyMarkdownRepair.repair(broken);
    expect(fixed, contains('```csharp\n'));
    expect(
      fixed,
      contains(
        '```csharp\n'
        'public class Demo\n'
        '{\n'
        '    public void Run() { }\n'
        '}\n'
        '```',
      ),
    );
    expect(fixed, isNot(contains('Demo\n\n{')));
  });

  test('CodeFenceCleanup normalizes corrupt fence markers', () {
    const broken = 'Hello\n```\uFFFD\uFFFD\nbody\n```\n';
    final fixed = StudyMarkdownRepair.repair(broken);
    expect(fixed, contains('```\nbody\n```'));
    expect(fixed, isNot(contains('\uFFFD')));
  });
}
