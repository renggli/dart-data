import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/worker/protocol.dart';

void main() {
  group('WorkerDispatcher', () {
    test(
      'evaluates cells, tracks staleness, recomputes, and supports undo/redo',
      () {
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
        check(dispatcher.document.mathCellById(2)?.value.toString())
            .equals('10');

        // Update cell 1 -> cell 2 becomes stale
        dispatcher.handle({
          'id': 3,
          'type': 'evalCell',
          'uid': uid1,
          'source': 'a := 4',
        });
        check(dispatcher.document.mathCellById(2)?.stale).equals(true);

        // Recompute stale -> cell 2 updates to 17
        dispatcher.handle({'id': 4, 'type': 'recomputeStale'});
        check(dispatcher.document.mathCellById(2)?.stale).equals(false);
        check(dispatcher.document.mathCellById(2)?.value.toString())
            .equals('17');

        // Undo & Redo
        dispatcher.handle({'id': 5, 'type': 'undo'});
        check(dispatcher.document.mathCellById(2)?.stale).equals(true);
        dispatcher.handle({'id': 6, 'type': 'redo'});
        check(dispatcher.document.mathCellById(2)?.value.toString())
            .equals('17');

        // Move & Delete
        dispatcher.handle({
          'id': 7,
          'type': 'moveCell',
          'uid': uid2,
          'newIndex': 0,
        });
        check(dispatcher.document.cells.first.uid).equals(uid2);
      },
    );

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
