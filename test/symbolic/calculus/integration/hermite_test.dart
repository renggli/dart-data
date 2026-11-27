import 'package:checks/checks.dart';
import 'package:data/src/symbolic/calculus/integration/hermite.dart';
import 'package:data/src/symbolic/poly/bridge.dart';
import 'package:data/src/symbolic/poly/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Hermite reduction', () {
    test(
      'separates rational antiderivative from repeated quadratic denominators',
      () {
        final numQ = PolyQ([IntegerNumber.one]); // 1
        final denQ = PolyQ([
          IntegerNumber.one,
          IntegerNumber.zero,
          IntegerNumber.one,
        ]); // x^2 + 1
        final res = hermiteReduce(numQ, denQ * denQ, 'x');

        check(res.den).equals(denQ);
        final recomposed =
            (res.rationalPart.derivative('x') +
                    polyQToExpr(res.num, 'x') / polyQToExpr(res.den, 'x'))
                .cancel();
        check((recomposed - Expr.parse('1 / (x^2 + 1)^2')).cancel())
            .equals(IntegerNumber.zero);
      },
    );

    test(
      'integrates high-multiplicity mixed rational functions via hermiteReduce',
      () {
        final expr = Expr.parse('(x^3 + 2) / ((x - 1)^2 * (x^2 + 1)^2)');
        final antideriv = expr.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        final residual = (antideriv.derivative('x') - expr).cancel();
        check(residual).equals(IntegerNumber.zero);
      },
    );

    test('integrates square-free cubic and quartic rational denominators', () {
      for (final source in [
        '(3*x^2 + 1) / (x^3 + x + 1)',
        '1 / ((x^2 + 1) * (x^2 + 2))',
        '(2*x + 5) / (x^2 - 2)',
      ]) {
        final expr = Expr.parse(source);
        final antideriv = expr.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        final diff = (antideriv.derivative('x') - expr).cancel();
        check(diff).equals(IntegerNumber.zero);
      }
    });
  });

  group('Phase 7 closed-form integration improvements', () {
    test(
      'integrates Chebyshev shift-angle trig products without expansion',
      () {
        final expr = Expr.parse('sin(101*x) * sin(x)^99');
        final antideriv = expr.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        final numericCheck = (antideriv.derivative('x') - expr).evaluate({
          'x': 0.37,
        });
        check(numericCheck.abs()).isLessThan(1e-10);
      },
    );

    test('integrates exp(x) times mixed transcendental sums', () {
      final expr = Expr.parse('exp(x) * (ln(1 + x^2) - 2*atan(x)*(1 + x))');
      final antideriv = expr.integrate('x');
      check(antideriv.anyNode((n) => n is Integral)).isFalse;
      final residual = (antideriv.derivative('x') - expr).expand().simplify();
      check(residual).equals(IntegerNumber.zero);
    });

    test(
      'integrates trig sum-to-product and (cos - sin) / F(sin(2x)) forms',
      () {
        final sumDiff = Expr.parse('sin(x + sin(x)) - sin(x - sin(x))');
        final sumDiffInt = sumDiff.integrate('x');
        check(sumDiffInt.anyNode((n) => n is Integral)).isFalse;
        check(
          (sumDiffInt.derivative('x') - sumDiff).evaluate({'x': 0.45}).abs(),
        ).isLessThan(1e-10);

        final sin2x = Expr.parse('(cos(x) - sin(x)) / (2 + sin(2*x))');
        final sin2xInt = sin2x.integrate('x');
        check(sin2xInt.anyNode((n) => n is Integral)).isFalse;
        check((sin2xInt.derivative('x') - sin2x).evaluate({'x': 0.45}).abs())
            .isLessThan(1e-10);
      },
    );

    test('integrates damped trig-over-x into complex Ei form', () {
      final expr = Expr.parse('sin(3*x) * exp(-2*x) / x');
      final antideriv = expr.integrate('x');
      check(antideriv.anyNode((n) => n is Integral)).isFalse;
      final dv = antideriv.derivative('x').evaluateComplex({
        'x': const Complex(0.7, 0),
      });
      final target = expr.evaluateComplex({'x': const Complex(0.7, 0)});
      check((dv.a - target.a).abs()).isLessThan(1e-10);
      check((dv.b - target.b).abs()).isLessThan(1e-10);
    });
  });
}
