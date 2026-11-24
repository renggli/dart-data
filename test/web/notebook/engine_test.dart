import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/engine/evaluator.dart';
import '../../../web/notebook/src/model/serialization.dart';
import '../../../web/notebook/src/model/value.dart';

void main() {
  group('NotebookEvaluator algebra & assumptions', () {
    test('evaluates simplify, expand, factor, and solve', () {
      final eval = NotebookEvaluator();
      check(eval.evaluate('simplify(x + x + 1)').value)
          .equals(ExprValue(Expr.parse('1 + 2*x')));
      check(eval.evaluate('cancel((x^2 - 1)/(x - 1))').value)
          .equals(ExprValue(Expr.parse('1 + x')));
      check(eval.evaluate('expand((x + 1)^2)').value)
          .equals(ExprValue(Expr.parse('1 + 2*x + x^2')));
      check(
        (eval.evaluate('solve(x^2 - 5*x + 6 = 0, x)').value as ListValue)
            .elements,
      ).unorderedEquals([
        const ExprValue(IntegerNumber.two),
        ExprValue(IntegerNumber.of(3)),
      ]);
    });

    test('respects assume and domain: positive', () {
      final eval = NotebookEvaluator();
      check(eval.evaluate("simplify(sqrt(x^2), domain: 'positive')").value)
          .equals(const ExprValue(Variable('x')));
      eval.evaluate("assume(y, 'positive')");
      check(eval.evaluate('sqrt(y^2)').value)
          .equals(const ExprValue(Variable('y')));
    });
  });

  group('NotebookEvaluator calculus & named options', () {
    test('evaluates diff, integrate, limit, series, and gradient', () {
      final eval = NotebookEvaluator();
      check(eval.evaluate('diff(x^3, x, order: 2)').value)
          .equals(ExprValue(Expr.parse('6*x')));
      check(eval.evaluate('integrate(sin(x), x, from: 0, to: pi)').value)
          .equals(const ExprValue(IntegerNumber.two));
      check(eval.evaluate("limit(1/x, x, 0, direction: 'right')").value)
          .equals(const ExprValue(Constant.infinity));
      check(eval.evaluate('series(exp(x), x, order: 3)').value)
          .isA<SeriesValue>();
      check(eval.evaluate('gradient(x^2 + y^2, [x, y])').value)
          .isA<VectorValue>();
    });
  });

  group('NotebookEvaluator plotting & numeric', () {
    test('builds 2D, parametric, 3D, complex, and ODE plots', () {
      final eval = NotebookEvaluator();
      final p2d = eval
          .evaluate("plot(sin(x), x, from: -pi, to: pi, title: 'Wave')")
          .value;
      check(p2d).isA<PlotValue>();
      check((p2d as PlotValue).title).equals('Wave');
      check(p2d.scene2d).isNotNull();
      check(p2d.scene2d!.datasets).isNotEmpty;

      final pParam = eval
          .evaluate('parametric(cos(t), sin(t), t, from: 0, to: 6.28)')
          .value;
      check((pParam as PlotValue).isParametric).isTrue;

      final p3d = eval.evaluate('plot3d(x^2 + y^2, x, y, grid: 16)').value;
      check((p3d as PlotValue).is3d).isTrue;
      check(p3d.plotKind).equals(PlotKind.surface3d);
      final roundTrip3d = valueFromJson(valueToJson(p3d)) as PlotValue;
      check(roundTrip3d.is3d).isTrue;
      check(roundTrip3d.plotKind).equals(PlotKind.surface3d);
      check(roundTrip3d.yVariable).equals('y');

      final pC = eval.evaluate('plotcomplex(z^2, z, contours: false)').value;
      check((pC as PlotValue).isComplex).isTrue;
      check(pC.showContours).isFalse;

      final pOde = eval
          .evaluate("ode(-y, y, t, y0: 1, from: 0, to: 2, method: 'rk4')")
          .value;
      check((pOde as PlotValue).isOde).isTrue;

      final pVf = eval.evaluate('vectorfield(-y, x, x, y, grid: 6)').value;
      check((pVf as PlotValue).scene2d).isNotNull();
      check(pVf.scene2d!.datasets).isNotEmpty;

      final pHm = eval.evaluate('heatmap(x^2 + y^2, x, y, grid: 16)').value;
      check((pHm as PlotValue).scene2d).isNotNull();

      final pVf3 = eval
          .evaluate('vectorfield3d(-y, x, z, x, y, z, grid: 3)')
          .value;
      check((pVf3 as PlotValue).is3d).isTrue;
    });

    test('evaluates nintegrate, nsolve, nminimize, and nderivative', () {
      final eval = NotebookEvaluator();
      final ni =
          eval.evaluate('nintegrate(x^2, x, from: 0, to: 1)').value
              as ExprValue;
      check(((ni.expr as RealNumber).value - 1.0 / 3.0).abs() < 1e-8).isTrue;

      final ns =
          eval.evaluate('nsolve(cos(x) = x, x, from: 0, to: 1)').value
              as ExprValue;
      check(((ns.expr as RealNumber).value - 0.7390851332).abs() < 1e-6).isTrue;

      final nm =
          eval.evaluate('nminimize((x - 2)^2 + 1, x, from: 0, to: 5)').value
              as ListValue;
      final xmin = ((nm.elements[0] as ExprValue).expr as RealNumber).value;
      check((xmin - 2.0).abs() < 1e-5).isTrue;

      final nd = eval.evaluate('nderivative(sin(x), x, 0)').value as ExprValue;
      check(((nd.expr as RealNumber).value - 1.0).abs() < 1e-5).isTrue;
    });
  });

  group('NotebookEvaluator linear, complex, numbers & user functions', () {
    test('evaluates matrix commands and vector ops', () {
      final eval = NotebookEvaluator();
      check(eval.evaluate('det([[1, 2], [3, 4]])').value)
          .equals(ExprValue(IntegerNumber.of(-2)));
      check(eval.evaluate('dot([1, 2, 3], [4, 5, 6])').value)
          .equals(ExprValue(IntegerNumber.of(32)));
      check(eval.evaluate('norm([3, 4])').value)
          .equals(ExprValue(IntegerNumber.of(5)));
    });

    test('evaluates user functions with optional and named defaults', () {
      final eval = NotebookEvaluator();
      eval.evaluate('wave(x, [amp = 1], {freq: 2}) := amp * sin(freq * x)');
      check(eval.evaluate('wave(x)').value)
          .equals(ExprValue(Expr.parse('sin(2*x)')));
      check(eval.evaluate('wave(x, 3, freq: 5)').value)
          .equals(ExprValue(Expr.parse('3*sin(5*x)')));
    });

    test('evaluates orthogonal polynomials via ExprSyntax', () {
      final eval = NotebookEvaluator();
      check(eval.evaluate('chebyshevT(3, x)').value)
          .equals(ExprValue(chebyshevT(3)));
    });
  });
}
