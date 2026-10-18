import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../web/calculator/src/engine/commands.dart';
import '../../../web/calculator/src/engine/evaluator.dart';
import '../../../web/calculator/src/engine/rpn.dart';
import '../../../web/calculator/src/model/environment.dart';
import '../../../web/calculator/src/model/session.dart';
import '../../../web/calculator/src/model/stack.dart';
import '../../../web/calculator/src/model/value.dart';

void main() {
  CalcEvaluator createEval() =>
      CalcEvaluator(environment: Environment(), session: Session());

  group('Representative Flows (Section 4.3)', () {
    test('Flow 4.3.1 (Scroll polynomial algebra and roots)', () {
      final eval = createEval();

      final c1 = eval.evaluateScroll('x^4 - 1');
      check(c1.id).equals(1);
      check(c1.value.toCanonicalText()).equals('-1 + x ^ 4');

      final c2 = eval.evaluateScroll('factor(r[1])');
      check(c2.id).equals(2);
      check(c2.value.toCanonicalText())
          .equals('(-1 + x) * (1 + x) * (1 + x ^ 2)');

      final c3 = eval.evaluateScroll('solve(r[1], x)');
      check(c3.id).equals(3);
      check(c3.value).isA<ListValue>();
      check((c3.value as ListValue).elements.length).equals(4);
    });

    test('Flow 4.3.2 (RPN Taylor expansion and plotting)', () {
      final eval = createEval();
      final stack = RpnStack();
      final rpn = RpnInterpreter(stack: stack, evaluator: eval);

      check(rpn.executeLine("'sin(x) / x'")).isNull();
      check(rpn.executeLine("'x'")).isNull();
      check(rpn.executeLine('0')).isNull();
      check(rpn.executeLine('4')).isNull();
      check(rpn.executeCommand('TAYL')).isNull();

      check(stack.depth).equals(1);
      check(stack.level(1).value.toCanonicalText())
          .equals('1 - 1/6 * x ^ 2 + 1/120 * x ^ 4');

      check(rpn.executeCommand('PLOT')).isNull();
      check(stack.level(1).value).isA<PlotValue>();
    });

    test('Flow 4.3.3 (Symbolic matrix determinant and inverse)', () {
      final eval = createEval();

      final c1 = eval.evaluateScroll('[[a, b], [c, d]]');
      check(c1.value).isA<MatrixValue>();

      final c2 = eval.evaluateScroll('det(r[1])');
      check(c2.value.toCanonicalText()).equals('a * d - b * c');

      final c3 = eval.evaluateScroll('inv([[2, 1], [1, 1]])');
      check(c3.value.toCanonicalText()).equals('[[1, -1], [-1, 2]]');
    });

    test('Flow 4.3.4 (Unevaluated integral and Numeric ∫ chip fallback)', () {
      final eval = createEval();

      final c1 = eval.evaluateScroll(
        'integrate(exp(-x^2) * cos(x^3), x, 0, 1)',
      );
      check(c1.value).isA<ExprValue>();
      // Chips for unevaluated definite integral include nintegrate ("Numeric ∫")
      final chips = CommandRegistry.chipsFor(c1.value);
      final numChip = chips.primary
          .where((c) => c.name == 'nintegrate')
          .firstOrNull;
      check(numChip).isNotNull();

      final call = numChip!.buildChipCall(c1.id, c1.value);
      final c2 = eval.evaluateScroll(call);
      check(c2.value.isExact).isFalse();
      check(double.parse(c2.value.toCanonicalText()))
          .isCloseTo(0.71478565, 1e-5);
    });
  });

  group('Command Categories & Evaluator', () {
    test('evaluates algebra, calculus, linear algebra, complex, numbers, numeric, and session commands', () {
      final eval = createEval();

      // Algebra
      check(eval.evaluateScroll('expand((x + 1)^2)').value.toCanonicalText())
          .equals('1 + 2 * x + x ^ 2');
      check(
        eval.evaluateScroll('apart(1 / (x^2 - 1), x)').value.toCanonicalText(),
      ).contains('1/2');
      check(
        eval.evaluateScroll('together(1 / x + 1 / y)').value.toCanonicalText(),
      ).equals('(x + y) / (x * y)');
      check(eval.evaluateScroll('subs(x^2 + y, x = 3)').value.toCanonicalText())
          .equals('9 + y');

      // Calculus
      check(eval.evaluateScroll('diff(x^3, x)').value.toCanonicalText())
          .equals('3 * x ^ 2');
      check(
        eval
            .evaluateScroll('integrate(sin(x), x, 0, pi)')
            .value
            .toCanonicalText(),
      ).equals('2');
      check(
        eval.evaluateScroll('limit(sin(x) / x, x, 0)').value.toCanonicalText(),
      ).equals('1');
      check(eval.evaluateScroll('sum(k, k, 1, n)').value.toCanonicalText())
          .equals('1/2 * n + 1/2 * n ^ 2');
      check(
        eval
            .evaluateScroll('gradient(x^2 + y^2, [x, y])')
            .value
            .toCanonicalText(),
      ).equals('[2 * x, 2 * y]');

      // Linear Algebra
      check(
        eval.evaluateScroll('trace([[2, 1], [3, 4]])').value.toCanonicalText(),
      ).equals('6');
      check(
        eval.evaluateScroll('rank([[1, 2], [2, 4]])').value.toCanonicalText(),
      ).equals('1');
      check(
        eval.evaluateScroll('rref([[1, 2], [2, 4]])').value.toCanonicalText(),
      ).equals('[[1, 2], [0, 0]]');
      check(
        eval
            .evaluateScroll('dot([1, 2, 3], [4, 5, 6])')
            .value
            .toCanonicalText(),
      ).equals('32');
      check(
        eval
            .evaluateScroll('cross([1, 0, 0], [0, 1, 0])')
            .value
            .toCanonicalText(),
      ).equals('[0, 0, 1]');

      // Complex
      check(eval.evaluateScroll('re(3 + 4 * i)').value.toCanonicalText())
          .equals('3');
      check(eval.evaluateScroll('im(3 + 4 * i)').value.toCanonicalText())
          .equals('4');
      check(eval.evaluateScroll('conj(3 + 4 * i)').value.toCanonicalText())
          .equals('3 - 4 * i');
      check(eval.evaluateScroll('abs(3 + 4 * i)').value.toCanonicalText())
          .equals('5');

      // Numbers
      check(eval.evaluateScroll('gcd(84, 126)').value.toCanonicalText())
          .equals('42');
      check(eval.evaluateScroll('lcm(12, 18)').value.toCanonicalText())
          .equals('36');
      check(eval.evaluateScroll('isprime(97)').value.toCanonicalText())
          .equals('1');
      check(eval.evaluateScroll('exact(0.75)').value.toCanonicalText())
          .equals('3/4');

      // Numeric
      final nsol = eval.evaluateScroll('nsolve(x^2 - 2 = 0, x, 1.5)');
      check(double.parse(nsol.value.toCanonicalText()))
          .isCloseTo(1.41421356, 1e-5);

      // Session variables & stale recompute
      final assignCell = eval.evaluateScroll('k := 3');
      final depCell = eval.evaluateScroll('k * x');
      check(depCell.value.toCanonicalText()).equals('3 * x');

      final (:cell, :staleIds) = eval.updateScrollCell(assignCell.id, 'k := 7');
      check(cell.value.toCanonicalText()).equals('7');
      check(staleIds).contains(depCell.id);

      eval.recomputeStaleCells();
      check(eval.session.allCells[depCell.id]!.value.toCanonicalText())
          .equals('7 * x');
    });

    test('handles discontinuities in plot(tan(x), x, -5, 5)', () {
      final eval = createEval();
      final plotCell = eval.evaluateScroll('plot(tan(x), x, -5, 5)');
      check(plotCell.value).isA<PlotValue>();
      final pv = plotCell.value as PlotValue;
      check(pv.curves).isNotEmpty();
      // tan(x) on [-5, 5] has 4 vertical asymptotes (±π/2, ±3π/2), splitting into multiple segments
      check(pv.curves.first.segments.length).isGreaterThan(3);
    });
  });
}
