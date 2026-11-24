import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/model/notebook.dart';
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
  });
}
