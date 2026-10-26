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
      // Note: r1 (r[1]) and r2 (r[2]) were pushed onto stack by evalScroll,
      // and updated in-place by updateScrollCell / recomputeStale!
      check(dispatcher.stack.depth).equals(2);
      check(dispatcher.stack.level(2).value.toCanonicalText()).equals('9');
      check(dispatcher.stack.level(1).value.toCanonicalText())
          .equals('1 + 9 * x');

      final r5 = dispatcher.handle(
        const WorkerRequest(
          id: 5,
          op: 'evalRpnLine',
          payload: {'line': '10 20 +'},
        ),
      );
      check(r5.ok).isTrue();
      check(dispatcher.stack.depth).equals(3);
      check(dispatcher.stack.level(1).value.toCanonicalText()).equals('30');
      // Intermediate literals 10 and 20 were coalesced from Session!
      check(dispatcher.session.activeCells.length).equals(3);

      // RPN line with forceNumeric: true approximates in-place without extra cell
      final rApprox = dispatcher.handle(
        const WorkerRequest(
          id: 50,
          op: 'evalRpnLine',
          payload: {'line': 'pi', 'forceNumeric': true},
        ),
      );
      check(rApprox.ok).isTrue();
      check(dispatcher.stack.depth).equals(4);
      check(dispatcher.stack.level(1).value.isExact).isFalse();
      check(dispatcher.session.activeCells.length).equals(4);
      check(dispatcher.session.activeCells.last.input).equals('pi');
      dispatcher.handle(
        const WorkerRequest(
          id: 51,
          op: 'execRpnCommand',
          payload: {'command': 'DROP'},
        ),
      );
      dispatcher.session.deleteCell(dispatcher.session.activeCells.last.id);

      final r6 = dispatcher.handle(
        const WorkerRequest(
          id: 6,
          op: 'execRpnCommand',
          payload: {'command': 'DUP'},
        ),
      );
      check(r6.ok).isTrue();
      check(dispatcher.stack.depth).equals(4);

      // Push cell 1 explicitly onto top of RPN stack
      final rPush = dispatcher.handle(
        const WorkerRequest(
          id: 7,
          op: 'pushCellToStack',
          payload: {'cellId': 1},
        ),
      );
      check(rPush.ok).isTrue();
      check(dispatcher.stack.depth).equals(5);
      check(dispatcher.stack.level(1).resultId).equals(1);
      check(dispatcher.stack.level(1).value.toCanonicalText()).equals('9');

      // Delete cell 1 removes all entries with resultId == 1 from stack
      final rDel = dispatcher.handle(
        const WorkerRequest(id: 8, op: 'deleteCell', payload: {'cellId': 1}),
      );
      check(rDel.ok).isTrue();
      check(dispatcher.stack.depth).equals(3);

      // Export and import state into a fresh WorkerDispatcher (simulating respawn after cancel)
      final snapshot = dispatcher.exportStateJson();
      final respawned = WorkerDispatcher();
      final rLoad = respawned.handle(
        WorkerRequest(id: 9, op: 'loadState', payload: {'state': snapshot}),
      );
      check(rLoad.ok).isTrue();
      check(respawned.session.activeCells.length)
          .equals(dispatcher.session.activeCells.length);
      check(respawned.stack.depth).equals(3);
      check(respawned.environment.getVariable('a')?.toCanonicalText())
          .equals('9');
    });

    test('supports unified whole-session undo and redo across Scroll and RPN operations', () {
      final dispatcher = WorkerDispatcher();
      check(dispatcher.canUndo).isFalse();
      check(dispatcher.canRedo).isFalse();

      // 1. Scroll variable assignment: k := 3
      dispatcher.handle(
        const WorkerRequest(
          id: 1,
          op: 'evalScroll',
          payload: {'input': 'k := 3'},
        ),
      );
      check(dispatcher.canUndo).isTrue();
      check(dispatcher.environment.getVariable('k')?.toCanonicalText())
          .equals('3');

      // 2. RPN line evaluation: 'x^2 - k^2' factor
      dispatcher.handle(
        const WorkerRequest(
          id: 2,
          op: 'evalRpnLine',
          payload: {'line': "'x^2 - k^2' factor"},
        ),
      );
      check(dispatcher.stack.depth).equals(2);
      check(dispatcher.stack.level(1).value.toCanonicalText())
          .equals('(-3 + x) * (3 + x)');
      check(dispatcher.session.activeCells.length).equals(2);

      // 3. Undo the RPN line evaluation
      final u1 = dispatcher.handle(const WorkerRequest(id: 3, op: 'undo'));
      check(u1.ok).isTrue();
      check(dispatcher.canRedo).isTrue();
      check(dispatcher.stack.depth).equals(1);
      check(dispatcher.stack.level(1).value.toCanonicalText()).equals('3');
      check(dispatcher.session.activeCells.length).equals(1);

      // 4. Undo the initial Scroll evaluation
      final u2 = dispatcher.handle(const WorkerRequest(id: 4, op: 'undo'));
      check(u2.ok).isTrue();
      check(dispatcher.canUndo).isFalse();
      check(dispatcher.stack.isEmpty).isTrue();
      check(dispatcher.session.activeCells).isEmpty();
      check(dispatcher.environment.getVariable('k')).isNull();

      // 5. Redo both steps
      dispatcher.handle(const WorkerRequest(id: 5, op: 'redo'));
      check(dispatcher.environment.getVariable('k')?.toCanonicalText())
          .equals('3');
      check(dispatcher.stack.depth).equals(1);

      dispatcher.handle(const WorkerRequest(id: 6, op: 'redo'));
      check(dispatcher.stack.depth).equals(2);
      check(dispatcher.stack.level(1).value.toCanonicalText())
          .equals('(-3 + x) * (3 + x)');
      check(dispatcher.canRedo).isFalse();
    });
  });
}
