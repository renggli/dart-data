import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../web/calculator/src/worker/protocol.dart';

void main() {
  group('WorkerDispatcher & Protocol', () {
    test('handles evalScroll, updateScrollCell, recomputeStale, evalRpnLine, and state replay', () {
      final dispatcher = WorkerDispatcher();

      final r1 = dispatcher.handle(
        const WorkerRequest(
          id: 1,
          op: 'evalScroll',
          payload: {'input': 'a := 5'},
        ),
      );
      check(r1.ok).isTrue();
      check(dispatcher.session.activeCells.length).equals(1);

      final r2 = dispatcher.handle(
        const WorkerRequest(
          id: 2,
          op: 'evalScroll',
          payload: {'input': 'a * x + 1'},
        ),
      );
      check(r2.ok).isTrue();
      final cell2 = r2.result!['cell']! as Map<String, Object?>;
      check((cell2['value']! as Map<String, Object?>)['text'])
          .equals('1 + 5 * x');

      // Update cell 1 and verify staleIds includes cell 2
      final r3 = dispatcher.handle(
        const WorkerRequest(
          id: 3,
          op: 'updateScrollCell',
          payload: {'cellId': 1, 'input': 'a := 9'},
        ),
      );
      check(r3.ok).isTrue();
      check(r3.result!['staleIds']! as List<Object?>).deepEquals([2]);

      // Recompute stale cells
      final r4 = dispatcher.handle(
        const WorkerRequest(id: 4, op: 'recomputeStale'),
      );
      check(r4.ok).isTrue();
      check(dispatcher.session.allCells[2]!.value.toCanonicalText())
          .equals('1 + 9 * x');

      // RPN line evaluation and command execution
      final r5 = dispatcher.handle(
        const WorkerRequest(
          id: 5,
          op: 'evalRpnLine',
          payload: {'line': '10 20 +'},
        ),
      );
      check(r5.ok).isTrue();
      check(dispatcher.stack.depth).equals(1);
      check(dispatcher.stack.level(1).value.toCanonicalText()).equals('30');

      final r6 = dispatcher.handle(
        const WorkerRequest(
          id: 6,
          op: 'execRpnCommand',
          payload: {'command': 'DUP'},
        ),
      );
      check(r6.ok).isTrue();
      check(dispatcher.stack.depth).equals(2);

      // Export and import state into a fresh WorkerDispatcher (simulating respawn after cancel)
      final snapshot = dispatcher.exportStateJson();
      final respawned = WorkerDispatcher();
      final rLoad = respawned.handle(
        WorkerRequest(id: 7, op: 'loadState', payload: {'state': snapshot}),
      );
      check(rLoad.ok).isTrue();
      check(respawned.session.activeCells.length)
          .equals(dispatcher.session.activeCells.length);
      check(respawned.stack.depth).equals(2);
      check(respawned.environment.getVariable('a')?.toCanonicalText())
          .equals('9');
    });
  });
}
