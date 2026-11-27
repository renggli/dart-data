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
        ExprValue(IntegerNumber.two),
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
          .equals(ExprValue(IntegerNumber.two));
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
      check(p2d.plotKind).equals(PlotKind.function2d);
      check(p2d.expressions.length).equals(1);

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
      check(pOde.odeMethod).equals('rk4');
      final roundTripOde = valueFromJson(valueToJson(pOde)) as PlotValue;
      check(roundTripOde.odeMethod).equals('rk4');

      final pVf = eval.evaluate('vectorfield(-y, x, x, y, grid: 6)').value;
      check((pVf as PlotValue).plotKind).equals(PlotKind.vectorField2d);
      check(pVf.gridSize).equals(6);

      final pHm = eval.evaluate('heatmap(x^2 + y^2, x, y, grid: 16)').value;
      check((pHm as PlotValue).plotKind).equals(PlotKind.heatmap2d);
      check(pHm.gridSize).equals(16);

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

    test(
      'evaluates orthogonal polynomials and special functions via ExprSyntax',
      () {
        final eval = NotebookEvaluator();
        check(eval.evaluate('chebyshevT(3, x)').value)
            .equals(ExprValue(chebyshevT(3)));
        check(eval.evaluate('logGamma(5)').value)
            .equals(ExprValue(Fn.logGamma(IntegerNumber.of(5))));
        final lgApprox =
            eval.evaluate('approx(logGamma(5))').value as ExprValue;
        check(((lgApprox.expr as RealNumber).value - 3.1780538303479458).abs())
            .isLessThan(1e-9);
        check(eval.evaluate('cbrt(8)').value)
            .equals(ExprValue(IntegerNumber.two));
        check(eval.evaluate('appellF1(1, 2, 3, 4, x, y)').value)
            .isA<ExprValue>();
      },
    );

    test('evaluates taylor without O-term, exact, rewrite, polydiv, and solvesystem', () {
      final eval = NotebookEvaluator();
      final tay =
          eval.evaluate('taylor(exp(x), x, order: 4)').value as ExprValue;
      check(tay.expr.anyNode((n) => n is OrderTerm)).isFalse;

      check(eval.evaluate('exact(0.75)').value)
          .equals(ExprValue(Expr.parse('3/4')));

      final rewritten = eval.evaluate("rewrite(sin(x), 'exp')").value;
      check(rewritten).isA<ExprValue>();

      final pd = eval.evaluate('polydiv(x^3 - 1, x - 1, x)').value as ListValue;
      check(pd.elements[0]).equals(ExprValue(Expr.parse('1 + x + x^2')));
      check(pd.elements[1]).equals(ExprValue(IntegerNumber.zero));

      final sys =
          eval.evaluate('solvesystem([x + y = 10, x - y = 2], [x, y])').value
              as ListValue;
      check(sys.elements.length).equals(1);
      final sol0 = sys.elements.first as ListValue;
      check(sol0.elements).unorderedEquals([
        ExprValue(Relational.equal(const Variable('x'), IntegerNumber.of(6))),
        ExprValue(Relational.equal(const Variable('y'), IntegerNumber.of(4))),
      ]);
    });

    test('evaluates rootsum, D, dsolve, antidiff, mintegrate, nminimize method, and nsolvesystem', () {
      final eval = NotebookEvaluator();
      final rsVal = eval.evaluate('rootsum(t^2 - 4, t, t^2)').value;
      check(rsVal).isA<ExprValue>();
      check((rsVal as ExprValue).expr).isA<RootSum>();
      final rsApprox =
          eval.evaluate('approx(rootsum(t^2 - 4, t, t^2))').value as ExprValue;
      check(((rsApprox.expr as RealNumber).value - 8.0).abs()).isLessThan(1e-9);

      eval.evaluate('y := 42'); // Ensure dsolve scopes y properly
      final odeSol = eval.evaluate('dsolve(D(y, x) - 2*y = 0, y, x)').value;
      check(odeSol).isA<ExprValue>();
      check(odeSol.toCanonicalText()).contains('exp(2 * x)');

      final ivp = eval
          .evaluate('dsolve(D(y, x) - 2*y = 0, y, x, at: 0, init: [3])')
          .value;
      check(ivp).equals(ExprValue(Expr.parse('3 * exp(2 * x)')));

      check(eval.evaluate('antidiff(1 / (x * (x + 1)), x)').value)
          .isA<ExprValue>();

      check(
        eval
            .evaluate('mintegrate(x * y, [y, x], from: [0, 0], to: [x, 1])')
            .value,
      ).equals(ExprValue(Expr.parse('1/8')));

      final nm =
          eval
                  .evaluate(
                    "nminimize((x - 2)^2 + 1, x, from: 0, to: 5, method: 'brent')",
                  )
                  .value
              as ListValue;
      final xmin = ((nm.elements[0] as ExprValue).expr as RealNumber).value;
      check((xmin - 2.0).abs() < 1e-5).isTrue;

      final nsys =
          eval
                  .evaluate(
                    'nsolvesystem([x + y - 10, x - y - 2], [x, y], [1, 1])',
                  )
                  .value
              as VectorValue;
      final x0 = (nsys.vector[0] as RealNumber).value;
      final y0 = (nsys.vector[1] as RealNumber).value;
      check((x0 - 6.0).abs() < 1e-6).isTrue;
      check((y0 - 4.0).abs() < 1e-6).isTrue;
    });
  });
}
