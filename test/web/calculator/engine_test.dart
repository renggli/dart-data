import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
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
      check(rpn.executeCommand('taylor')).isNull();

      check(stack.depth).equals(1);
      check(stack.level(1).value.toCanonicalText())
          .equals('1 - 1/6 * x ^ 2 + 1/120 * x ^ 4');

      check(rpn.executeCommand('plot')).isNull();
      check(stack.level(1).value).isA<PlotValue>();
    });

    test('RPN accepts canonical and humanized command names', () {
      final eval = createEval();
      final stack = RpnStack();
      final rpn = RpnInterpreter(stack: stack, evaluator: eval);

      // Humanized command names
      check(rpn.executeLine("'x^2 - 1'")).isNull();
      check(rpn.executeCommand('Factor')).isNull();
      check(stack.level(1).value.toCanonicalText())
          .equals('(-1 + x) * (1 + x)');

      check(rpn.executeCommand('Expand')).isNull();
      check(stack.level(1).value.toCanonicalText()).equals('-1 + x ^ 2');

      // Duplicate and Drop
      check(rpn.executeCommand('Duplicate')).isNull();
      check(stack.depth).equals(2);
      check(rpn.executeCommand('Drop')).isNull();
      check(stack.depth).equals(1);

      // Store, Recall, and Delete
      check(rpn.executeLine("'my_var'")).isNull();
      check(rpn.executeCommand('Store')).isNull();
      check(rpn.executeLine("'my_var'")).isNull();
      check(rpn.executeCommand('Recall')).isNull();
      check(stack.level(1).value.toCanonicalText()).equals('-1 + x ^ 2');

      check(rpn.executeLine("'my_var'")).isNull();
      check(rpn.executeCommand('Delete')).isNull();
      check(eval.environment.getVariable('my_var')).isNull();

      // Approx and Exact
      check(rpn.executeLine("'1/2'")).isNull();
      check(rpn.executeCommand('Approx')).isNull();
      check(stack.level(1).value.toCanonicalText()).equals('0.5');
      check(rpn.executeCommand('Exact')).isNull();
      check(stack.level(1).value.toCanonicalText()).equals('1/2');
    });

    test('RPN operations are atomic and transactional on error', () {
      final eval = createEval();
      final stack = RpnStack();
      final rpn = RpnInterpreter(stack: stack, evaluator: eval);

      // 1. Singular matrix inversion does not discard the matrix
      check(rpn.executeLine('[[1, 2], [2, 4]]')).isNull();
      check(stack.depth).equals(1);
      final invErr = rpn.executeCommand('inv');
      check(invErr).isNotNull();
      check(stack.depth).equals(1);
      check(stack.level(1).value.toCanonicalText()).equals('[[1, 2], [2, 4]]');

      // 2. Incompatible dimension cross product does not discard vector operands
      check(rpn.executeLine('[1, 2]')).isNull();
      check(rpn.executeLine('[3, 4]')).isNull();
      check(stack.depth).equals(3);
      final crossErr = rpn.executeCommand('cross');
      check(crossErr).isNotNull();
      check(stack.depth).equals(3);
      check(stack.level(1).value.toCanonicalText()).equals('[3, 4]');
      check(stack.level(2).value.toCanonicalText()).equals('[1, 2]');

      // 3. Multi-token line with mid-stream error rolls back completely
      final multiErr = rpn.executeLine('[5, 6] [7, 8] cross');
      check(multiErr).isNotNull();
      // Only the 3 previous items remain from before the line
      check(stack.depth).equals(3);
      check(stack.level(1).value.toCanonicalText()).equals('[3, 4]');
    });

    test('Flow 4.3.2b (Parameterized RPN stack roll, pick, and drop)', () {
      final eval = createEval();
      final stack = RpnStack();
      final rpn = RpnInterpreter(stack: stack, evaluator: eval);

      rpn.executeLine('10 20 30 40');
      check(stack.depth).equals(4);
      // Stack is bottom [10, 20, 30, 40] top (level 1 is 40, level 4 is 10)
      check(stack.level(1).value.toCanonicalText()).equals('40');
      check(stack.level(4).value.toCanonicalText()).equals('10');

      // '3 ROLL' moves level 3 (20) to level 1
      check(rpn.executeCommand('3 ROLL')).isNull();
      check(stack.depth).equals(4);
      check(stack.level(1).value.toCanonicalText()).equals('20');
      check(stack.level(2).value.toCanonicalText()).equals('40');
      check(stack.level(3).value.toCanonicalText()).equals('30');
      check(stack.level(4).value.toCanonicalText()).equals('10');

      // '2 DROP' removes level 2 (40)
      check(rpn.executeCommand('2 DROP')).isNull();
      check(stack.depth).equals(3);
      check(stack.level(1).value.toCanonicalText()).equals('20');
      check(stack.level(2).value.toCanonicalText()).equals('30');
      check(stack.level(3).value.toCanonicalText()).equals('10');

      // '3 PICK' copies level 3 (10) to top
      check(rpn.executeCommand('3 PICK')).isNull();
      check(stack.depth).equals(4);
      check(stack.level(1).value.toCanonicalText()).equals('10');
      check(stack.level(2).value.toCanonicalText()).equals('20');
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
      check(double.parse(c2.value.toCanonicalText())).isCloseTo(0.7148, 1e-5);
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
      check(double.parse(nsol.value.toCanonicalText())).isCloseTo(1.4142, 1e-5);

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

    test(
      'supports 1-argument smart variable inference in Scroll and RPN modes',
      () {
        final eval = createEval();
        final stack = RpnStack();
        final rpn = RpnInterpreter(stack: stack, evaluator: eval);

        // Scroll 1-arg calls
        check(eval.evaluateScroll('solve(x^2 - 9)').value.toCanonicalText())
            .equals('[3, -3]');
        check(eval.evaluateScroll('diff(sin(t))').value.toCanonicalText())
            .equals('cos(t)');
        check(eval.evaluateScroll('integrate(3 * x^2)').value.toCanonicalText())
            .equals('x ^ 3');
        check(eval.evaluateScroll('taylor(exp(x))').value.toCanonicalText())
            .contains('1/120 * x ^ 5');
        check(eval.evaluateScroll('limit(sin(x) / x)').value.toCanonicalText())
            .equals('1');
        check(eval.evaluateScroll('plot(sin(x))').value).isA<PlotValue>();

        // RPN 1-item stack execution
        check(rpn.executeLine("'x^2 - 9' solve")).isNull();
        check(stack.level(1).value.toCanonicalText()).equals('[3, -3]');

        check(rpn.executeLine("'sin(t)' diff")).isNull();
        check(stack.level(1).value.toCanonicalText()).equals('cos(t)');

        check(rpn.executeLine("'3 * x^2' integrate")).isNull();
        check(stack.level(1).value.toCanonicalText()).equals('x ^ 3');

        check(rpn.executeLine("'exp(x)' taylor")).isNull();
        check(stack.level(1).value.toCanonicalText()).contains('1/120 * x ^ 5');

        // RPN 2-item taylor (expr + order)
        check(rpn.executeLine("'cos(x)' 2 taylor")).isNull();
        check(stack.level(1).value.toCanonicalText()).equals('1 - 1/2 * x ^ 2');

        // RPN 3-item definite integral (expr, lower, upper)
        check(rpn.executeLine("'sin(x)' 0 pi DEF∫")).isNull();
        check(stack.level(1).value.toCanonicalText()).equals('2');
      },
    );

    test('synchronizes Scroll evaluations onto RPN stack and coalesces RPN literal pushes', () {
      final env = Environment();
      final session = Session();
      final stack = RpnStack();
      final eval = CalcEvaluator(
        environment: env,
        session: session,
        stack: stack,
      );
      final rpn = RpnInterpreter(stack: stack, evaluator: eval);

      // Scroll evaluation pushes onto RPN stack
      final c1 = eval.evaluateScroll('x^2 - 1');
      check(stack.depth).equals(1);
      check(stack.level(1).resultId).equals(c1.id);
      check(stack.level(1).value.toCanonicalText()).equals('-1 + x ^ 2');

      // RPN command operates directly on the Scroll result on stack level 1:
      // Note: c1 is NOT a literal push, so c1 remains in Session while factor creates c2!
      check(rpn.executeCommand('factor')).isNull();
      check(stack.depth).equals(1);
      check(stack.level(1).value.toCanonicalText())
          .equals('(-1 + x) * (1 + x)');
      check(session.activeCells.length).equals(2);

      // RPN literal pushes ('12 4 +') coalesce the literal pushes 12 and 4
      check(rpn.executeLine('12 4 +')).isNull();
      check(stack.depth).equals(2);
      check(stack.level(1).value.toCanonicalText()).equals('16');
      // Only the final result cell (12 + 4 = 16) remains in Session alongside c1 and c2
      check(session.activeCells.length).equals(3);
    });

    test('supports analyze, parametric plots, ODE plots, and parameterized PlotValue', () {
      final eval = createEval();

      // 1. analyze(x^3 - 3 * x)
      final analysis = eval.evaluateScroll('analyze(x^3 - 3 * x)');
      check(analysis.value).isA<ListValue>();
      final text = analysis.value.toCanonicalText();
      check(text).contains('parity == odd');
      check(text).contains('f0 == 0');
      check(text).contains('crit == 1');
      check(text).contains('crit == -1');
      check(text).contains('infl == 0');

      // 2. Parametric plot: plot([cos(t), sin(t)], t, 0, 6.28)
      final paramCell = eval.evaluateScroll(
        'plot([cos(t), sin(t)], t, 0, 6.28)',
      );
      check(paramCell.value).isA<PlotValue>();
      final paramPlot = paramCell.value as PlotValue;
      check(paramPlot.isParametric).isTrue();
      check(paramPlot.curves.length).equals(1);
      check(paramPlot.curves.first.segments).isNotEmpty();

      // 3. ODE plot: ode(-y, 1, 0, 2)
      final odeCell = eval.evaluateScroll('ode(-y, 1, 0, 2)');
      check(odeCell.value).isA<PlotValue>();
      final odePlot = odeCell.value as PlotValue;
      check(odePlot.curves.length).equals(1);
      final lastY = odePlot.curves.first.segments.first.y.last;
      check(lastY).isCloseTo(0.135335, 1e-3); // exp(-2) ≈ 0.135335

      // 4. Parameterized plot: plot(sin(a * x + b), x, -5, 5)
      final sliderCell = eval.evaluateScroll('plot(sin(a * x + b), x, -5, 5)');
      check(sliderCell.value).isA<PlotValue>();
      final sliderPlot = sliderCell.value as PlotValue;
      check(sliderPlot.parameters).deepEquals(['a', 'b']);

      // 5. 3D Surface plot: plot3d(x^2 - y^2) (1-arg smart variable inference)
      final surfCell = eval.evaluateScroll('plot3d(x^2 - y^2)');
      check(surfCell.value).isA<PlotValue>();
      final surfPlot = surfCell.value as PlotValue;
      check(surfPlot.is3d).isTrue();
      check(surfPlot.surface3d!.xVar).equals('x');
      check(surfPlot.surface3d!.yVar).equals('y');
      check(surfPlot.surface3d!.gridSize).equals(64);
      check(surfPlot.surface3d!.zValues.length).equals(64 * 64);

      // 6. RPN plot3d and Plot 3D primary chip on 2-variable ExprValue
      final bivarCell = eval.evaluateScroll('sin(sqrt(x^2 + y^2))');
      final chips = CommandRegistry.chipsFor(bivarCell.value);
      check(chips.primary.map((c) => c.name)).contains('plot3d');

      final rpn = RpnInterpreter(stack: RpnStack(), evaluator: eval);
      check(rpn.executeLine("'x * exp(-x^2 - y^2)' plot3d")).isNull();
      check(rpn.stack.level(1).value).isA<PlotValue>();
      check((rpn.stack.level(1).value as PlotValue).is3d).isTrue();

      // 7. Unquoted symbolic RPN postfix quick-start lines & forceNumeric
      check(rpn.executeLine('x 6 ^ 1 - factor')).isNull();
      check(rpn.stack.level(1).value.toCanonicalText()).contains('-1 + x');
      check(rpn.executeLine('x 3 ^ 6 x 2 ^ * - 11 x * + 6 - solve')).isNull();
      check(rpn.stack.level(1).value.toCanonicalText()).equals('[3, 2, 1]');
      check(rpn.executeLine('x 2 ^ x cos * integrate')).isNull();
      check(rpn.stack.level(1).value).isA<ExprValue>();
      check(rpn.executeLine('x sin x / 0 6 taylor')).isNull();
      check(rpn.stack.level(1).value.toCanonicalText()).contains('x ^ 6');
      check(rpn.executeLine('[[a, b], [c, d]] inv')).isNull();
      check(rpn.stack.level(1).value).isA<MatrixValue>();
      check(rpn.executeLine('[sin(x) / x, cos(x)] -10 10 plot')).isNull();
      check(rpn.stack.level(1).value).isA<PlotValue>();
      check((rpn.stack.level(1).value as PlotValue).curves.length).equals(2);
      final cellsBeforeApprox = eval.session.activeCells.length;
      check(rpn.executeLine('pi', forceNumeric: true)).isNull();
      check(rpn.stack.level(1).value.isExact).isFalse();
      check(rpn.stack.level(1).isLiteralPush).isTrue();
      // Single cell created for 'pi' (approximated in-place), no extra approx(...) cell
      check(eval.session.activeCells.length).equals(cellsBeforeApprox + 1);
      check(eval.session.activeCells.last.input).equals('pi');
    });

    test('simultaneous user function substitution, approx digits, and deg mode', () {
      final env = Environment();
      final session = Session();
      final eval = CalcEvaluator(environment: env, session: session);

      // Simultaneous parameter substitution without variable capture
      eval.evaluateScroll('f(x, y) := x + 2 * y');
      final swapped = eval.evaluateScroll('f(y, x)');
      check(swapped.value.toCanonicalText()).equals('2 * x + y');

      // approx(expr, digits)
      final approx4 = eval.evaluateScroll('approx(pi, 4)');
      check(approx4.value.toCanonicalText()).equals('3.142');

      // AngleMode.deg on sec/csc/cot and inverse trig
      env.settings = env.settings.copyWith(angleMode: AngleMode.deg);
      check(eval.evaluateScroll('sec(60)').value.toCanonicalText()).equals('2');
      check(eval.evaluateScroll('asin(1 / 2)').value.toCanonicalText())
          .equals('30');
      env.settings = env.settings.copyWith(angleMode: AngleMode.rad);

      // Assumptions propagation in Vector/Matrix simplification
      env.settings = env.settings.copyWith(domain: VariableDomain.positive);
      check(eval.evaluateScroll('[sqrt(x^2)]').value.toCanonicalText())
          .equals('[x]');
      env.settings = env.settings.copyWith(domain: VariableDomain.real);

      // RPN ComplexDisplayMode.polar parity
      env.settings = env.settings.copyWith(
        complexDisplay: ComplexDisplayMode.polar,
      );
      final rpn = RpnInterpreter(stack: RpnStack(), evaluator: eval);
      check(rpn.executeLine('1 i +')).isNull();
      check(rpn.stack.level(1).value.toCanonicalText()).contains('exp(');
      env.settings = env.settings.copyWith(
        complexDisplay: ComplexDisplayMode.rect,
      );

      // Bound parameter and dummy variable shadowing of i, e, pi
      eval.evaluateScroll('sq(i) := i^2');
      check(eval.evaluateScroll('sq(5)').value.toCanonicalText()).equals('25');
      check(eval.evaluateScroll('sum(i, i, 1, 10)').value.toCanonicalText())
          .equals('55');
      check(eval.evaluateScroll('diff(e^2, e)').value.toCanonicalText())
          .equals('2 * e');

      // AngleMode.deg plotting does not double-scale constant trig subexpressions
      env.settings = env.settings.copyWith(angleMode: AngleMode.deg);
      final degPlot =
          eval.evaluateScroll('plot(sin(x) + sin(30), x, 0, 90)').value
              as PlotValue;
      final seg = degPlot.curves.first.segments.first;
      // At x = 0, sin(0) + sin(30°) = 0.5; at x = 90, sin(90°) + sin(30°) = 1.5
      check(seg.y.first).isCloseTo(0.5, 1e-6);
      check(seg.y.last).isCloseTo(1.5, 1e-6);

      final asinPlot =
          eval.evaluateScroll('plot(asin(x), x, 0, 1)').value as PlotValue;
      check(asinPlot.curves.first.segments.first.y.last).isCloseTo(90.0, 1e-4);
    });
  });
}
