import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/model/notebook.dart';
import '../../../web/notebook/src/model/serialization.dart';
import '../../../web/notebook/src/model/value.dart';

void main() {
  group('NotebookDocument', () {
    test('inserts, moves, converts, and deletes cells with tombstones', () {
      final doc = NotebookDocument();
      final m1 = doc.insertMathCell('a := 5');
      m1
        ..value = ExprValue(IntegerNumber.of(5))
        ..assignedSymbol = 'a';
      final md = doc.insertMarkdownCell('Result is {{r[1]}} and {{a}}.');
      final m2 = doc.insertMathCell('r[1] + a');
      m2
        ..referencedResults = {1}
        ..referencedSymbols = {'a'};

      check(doc.cells.length).equals(3);
      check(md.referencedResults).contains(1);
      check(md.referencedSymbols).contains('a');

      // Delete m1 -> tombstone preserved for r[1], dependents marked stale
      doc.deleteCell(m1.uid);
      check(doc.lookupResult(1)).equals(ExprValue(IntegerNumber.of(5)));
      check(m2.stale).isTrue;
      check(md.stale).isTrue;

      // Convert markdown to math
      final converted = doc.convertCellType(md.uid);
      check(converted).isA<MathCell>();
    });

    test('exports and imports portable Markdown and JSON snapshots', () {
      final doc = NotebookDocument();
      doc.insertMarkdownCell('# Title\n\nSome prose.');
      doc.insertMathCell('x^2 + 1');

      final mdText = doc.toMarkdown();
      check(mdText).contains('# Title');
      check(mdText).contains('```math\nx^2 + 1\n```');

      final doc2 = NotebookDocument()..loadFromMarkdown(mdText);
      check(doc2.cells.length).equals(2);
      check(doc2.cells[0]).isA<MarkdownCell>();
      check(doc2.cells[1]).isA<MathCell>();

      final doc3 = NotebookDocument()..loadFromJson(doc.toJson());
      check(doc3.cells.length).equals(2);
    });

    test('splits headings to the top of adjacent markdown cells', () {
      const md = '''
# Document Title

Intro paragraph.

## First Section

```python
# comment inside code fence
x = 1
```

Trailing prose.

## Second Section

Follow-up prose.

```math
1 + 1
```
''';
      final doc = NotebookDocument()..loadFromMarkdown(md);
      check(doc.cells.length).equals(4);
      check(doc.cells[0]).isA<MarkdownCell>();
      check(doc.cells[0].source)
        ..startsWith('# Document Title')
        ..contains('Intro paragraph.');
      check(doc.cells[1]).isA<MarkdownCell>();
      check(doc.cells[1].source)
        ..startsWith('## First Section')
        ..contains('# comment inside code fence')
        ..contains('Trailing prose.');
      check(doc.cells[2]).isA<MarkdownCell>();
      check(doc.cells[2].source)
        ..startsWith('## Second Section')
        ..contains('Follow-up prose.');
      check(doc.cells[3]).isA<MathCell>();
      check(doc.cells[3].source).equals('1 + 1');

      final reloaded = NotebookDocument()..loadFromMarkdown(doc.toMarkdown());
      check(reloaded.cells.length).equals(4);
      check(reloaded.cells[2].source).equals(doc.cells[2].source);
    });

    test(
      'serialization preserves factored integer and rational AST structure',
      () {
        for (final raw in ['12', '-12', '360', '12/25']) {
          final factored = Expr.parse(raw).factor();
          final roundTripped =
              valueFromJson(valueToJson(ExprValue(factored))) as ExprValue;
          check(roundTripped.expr.toMathMl()).equals(factored.toMathMl());
          check(roundTripped.expr.toLatex()).equals(factored.toLatex());
        }
      },
    );
  });
}
