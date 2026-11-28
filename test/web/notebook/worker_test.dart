import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/model/notebook.dart';
import '../../../web/notebook/src/model/value.dart';
import '../../../web/notebook/src/worker/protocol.dart';

void main() {
  group('WorkerDispatcher', () {
    test('evaluates cells, propagates dependent updates automatically, and supports undo/redo', () {
      final dispatcher = WorkerDispatcher();

      final r1 = dispatcher.handle({
        'id': 1,
        'type': 'evalCell',
        'source': 'a := 3',
      });
      check(r1['ok']).equals(true);
      final uid1 = r1['evaluatedUid']! as String;

      final r2 = dispatcher.handle({
        'id': 2,
        'type': 'evalCell',
        'source': 'a^2 + 1',
      });
      check(r2['ok']).equals(true);
      final uid2 = r2['evaluatedUid']! as String;
      check(dispatcher.document.mathCellById(2)?.value.toString()).equals('10');

      // Update cell 1 -> cell 2 updates automatically without going stale
      dispatcher.handle({
        'id': 3,
        'type': 'evalCell',
        'uid': uid1,
        'source': 'a := 4',
      });
      check(dispatcher.document.mathCellById(2)?.stale).equals(false);
      check(dispatcher.document.mathCellById(2)?.value.toString()).equals('17');

      // Undo & Redo
      dispatcher.handle({'id': 4, 'type': 'undo'});
      check(dispatcher.document.mathCellById(2)?.value.toString()).equals('10');
      dispatcher.handle({'id': 5, 'type': 'redo'});
      check(dispatcher.document.mathCellById(2)?.value.toString()).equals('17');

      // Move cell 2 to top
      dispatcher.handle({
        'id': 6,
        'type': 'moveCell',
        'uid': uid2,
        'newIndex': 0,
      });
      check(dispatcher.document.cells.first.uid).equals(uid2);
    });

    test('handles unbound plot recovery, slider/input controls, diamond DAGs, and cycles', () {
      final dispatcher = WorkerDispatcher();

      // Add plot with unbound variable BEFORE defining variable -> error, sibling intact
      final pRes = dispatcher.handle({
        'id': 1,
        'type': 'evalCell',
        'source': 'plot(a * sin(x) + b, x, x: -pi..pi)',
      });
      final plotUid = pRes['evaluatedUid']! as String;
      check(dispatcher.document.mathCellById(1)?.value).isA<ErrorValue>();

      dispatcher.handle({'id': 2, 'type': 'evalCell', 'source': '1 + 1'});
      check(dispatcher.document.mathCellById(2)?.value.toString()).equals('2');

      // Insert interactive controls above plot -> plot automatically recovers
      final cRes = dispatcher.handle({
        'id': 3,
        'type': 'evalCell',
        'index': 0,
        'source': "a := slider(-1..1, default: 0, label: 'value a');\nb := input(pi, label: 'value: b');",
      });
      final ctrlUid = cRes['evaluatedUid']! as String;
      final plotCell = dispatcher.document.cellByUid(plotUid)! as MathCell;
      check(plotCell.value).isA<PlotValue>();

      // Update slider & formula input -> downstream plot updates live
      dispatcher.handle({
        'id': 4,
        'type': 'updateControl',
        'uid': ctrlUid,
        'key': 'a',
        'value': 0.5,
        'recordUndo': false,
      });
      dispatcher.handle({
        'id': 5,
        'type': 'updateControl',
        'uid': ctrlUid,
        'key': 'b',
        'value': 'cos(x)',
        'recordUndo': true,
      });
      final updatedPlot =
          dispatcher.document.mathCellById(1)?.value as PlotValue;
      check(updatedPlot.expressions.first.toString()).contains('cos(x)');

      // Undo formula change -> reverts b back to pi cleanly
      dispatcher.handle({'id': 6, 'type': 'undo'});
      final revertedPlot =
          dispatcher.document.mathCellById(1)?.value as PlotValue;
      check(revertedPlot.expressions.first.toString()).contains('pi');

      // Diamond dependency updates bottom node once cleanly
      final topUid =
          dispatcher.handle({
                'id': 7,
                'type': 'evalCell',
                'source': 'x0 := 2',
              })['evaluatedUid']!
              as String;
      final d1 =
          dispatcher.handle({
                'id': 8,
                'type': 'evalCell',
                'source': 'x1 := x0 + 1',
              })['evaluatedUid']!
              as String;
      final d2 =
          dispatcher.handle({
                'id': 9,
                'type': 'evalCell',
                'source': 'x2 := x0 * 3',
              })['evaluatedUid']!
              as String;
      final d3 =
          dispatcher.handle({
                'id': 10,
                'type': 'evalCell',
                'source': 'x1 + x2',
              })['evaluatedUid']!
              as String;
      check((dispatcher.document.cellByUid(d3)! as MathCell).value.toString())
          .equals('9');
      dispatcher.handle({
        'id': 11,
        'type': 'evalCell',
        'uid': topUid,
        'source': 'x0 := 5',
      });
      check((dispatcher.document.cellByUid(d1)! as MathCell).value.toString())
          .equals('6');
      check((dispatcher.document.cellByUid(d2)! as MathCell).value.toString())
          .equals('15');
      check((dispatcher.document.cellByUid(d3)! as MathCell).value.toString())
          .equals('21');

      // Mutual circular dependencies are flagged cleanly without looping
      final cyc1 =
          dispatcher.handle({
                'id': 12,
                'type': 'evalCell',
                'source': 'p0 := q0 + 1',
              })['evaluatedUid']!
              as String;
      final cyc2 =
          dispatcher.handle({
                'id': 13,
                'type': 'evalCell',
                'source': 'q0 := p0 + 1',
              })['evaluatedUid']!
              as String;
      check((dispatcher.document.cellByUid(cyc1)! as MathCell).value)
          .isA<ErrorValue>();
      check((dispatcher.document.cellByUid(cyc2)! as MathCell).value)
          .isA<ErrorValue>();
    });

    test('imports and exports Markdown notebooks', () {
      final dispatcher = WorkerDispatcher();
      dispatcher.handle({
        'id': 1,
        'type': 'importMarkdown',
        'markdown': '# Demo\n\n```math\n2 + 3\n```',
      });
      check(dispatcher.document.cells.length).equals(2);
      check(dispatcher.document.mathCellById(1)?.value.toString()).equals('5');

      final exported = dispatcher.handle({'id': 2, 'type': 'exportMarkdown'});
      check(exported['markdown']! as String).contains('```math\n2 + 3\n```');
    });
  });
}
