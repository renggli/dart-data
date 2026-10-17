import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/transcendental.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Inverse trigonometric and hyperbolic equations', () {
    test('solves Asin, Acos, and Atan equations and checks range bounds', () {
      check(Expr.parse('asin(x) - pi/6').solve('x').first.evaluate())
          .isCloseTo(0.5, 1e-12);
      check(Expr.parse('asin(x) - 2').solve('x')).isEmpty();

      check(Expr.parse('acos(x) - pi/3').solve('x').first.evaluate())
          .isCloseTo(0.5, 1e-12);
      check(Expr.parse('acos(x) + 1').solve('x')).isEmpty();
      check(Expr.parse('acos(x) - 4').solve('x')).isEmpty();

      check(Expr.parse('atan(x) - pi/4').solve('x').first.evaluate())
          .isCloseTo(1.0, 1e-12);
      check(Expr.parse('atan(x) - 2').solve('x')).isEmpty();
      check(Expr.parse('atan(x) + 2').solve('x')).isEmpty();
    });

    test('solves Sinh, Cosh, Tanh, Asinh, Acosh, Atanh, Abs, and Erf', () {
      const x = Variable('x');
      check(Sinh(x).solve('x')).deepEquals([IntegerNumber.zero]);
      check((Sinh(x) - IntegerNumber.two).solve('x'))
          .deepEquals([Asinh(IntegerNumber.two)]);

      check((Cosh(x) - FractionNumber.half).solve('x')).isEmpty();
      check((Cosh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([IntegerNumber.zero]);
      check((Cosh(x) - IntegerNumber.two).solve('x')).unorderedEquals([
        Acosh(IntegerNumber.two),
        (-Acosh(IntegerNumber.two)).simplify(),
      ]);

      check((Tanh(x) - IntegerNumber.one).solve('x')).isEmpty();
      check((Tanh(x) + IntegerNumber.two).solve('x')).isEmpty();
      check((Tanh(x) - FractionNumber.half).solve('x'))
          .deepEquals([Atanh(FractionNumber.half)]);

      check((Asinh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([Sinh(IntegerNumber.one)]);

      check((Acosh(x) + IntegerNumber.one).solve('x')).isEmpty();
      check((Acosh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([Cosh(IntegerNumber.one)]);

      check((Atanh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([Tanh(IntegerNumber.one)]);

      check((Abs(x) + IntegerNumber.one).solve('x')).isEmpty();
      check(Abs(x - IntegerNumber.of(3)).solve('x'))
          .deepEquals([IntegerNumber.of(3)]);
      check((Abs(x - IntegerNumber.one) - IntegerNumber.two).solve('x'))
          .unorderedEquals([IntegerNumber.negativeOne, IntegerNumber.of(3)]);

      check(Erf(x - IntegerNumber.two).solve('x'))
          .deepEquals([IntegerNumber.two]);
      check((Erf(x) - IntegerNumber.two).solve('x')).isEmpty();
      check((Erf(x) - FractionNumber.half).solve('x')).isEmpty();
    });
  });

  group('Exponential, power, and radical equations', () {
    test('solves e^f(x) = c and b^f(x) = c', () {
      check(Expr.parse('exp(x) + 1').solve('x')).isEmpty();
      check(Expr.parse('exp(2*x) - 1').solve('x'))
          .deepEquals([IntegerNumber.zero]);

      check(Expr.parse('2^x + 1').solve('x')).isEmpty();
      final twoPow = Expr.parse('2^x - 8').solve('x');
      check(twoPow.length).equals(1);
      check(twoPow.first.evaluate()).isCloseTo(3.0, 1e-12);

      // Symbolic base
      final symPow = Expr.parse('a^x - b').solve('x');
      check(symPow).deepEquals([
        (Ln(const Variable('b')) / Ln(const Variable('a'))).simplify(),
      ]);
    });

    test('solves even, odd, negative, and fractional power equations', () {
      const x = Variable('x');
      // Negative power equal to 0 has no solution
      check(
        invertEquation(
          Pow(x + IntegerNumber.one, IntegerNumber.of(-2)),
          IntegerNumber.zero,
          'x',
        ),
      ).isNotNull().isEmpty();

      // Even integer power
      check(
        invertEquation(
          Pow(x + IntegerNumber.one, IntegerNumber.two),
          IntegerNumber.of(-4),
          'x',
        ),
      ).isNotNull().isEmpty();
      check(
        invertEquation(
          Pow(x + IntegerNumber.one, IntegerNumber.two),
          const RealNumber(-4.0),
          'x',
        ),
      ).isNotNull().isEmpty();
      check(
            invertEquation(
              Pow(x - IntegerNumber.one, IntegerNumber.two),
              IntegerNumber.of(9),
              'x',
            ),
          )
          .isNotNull()
          .unorderedEquals([IntegerNumber.of(-2), IntegerNumber.of(4)]);

      // Odd integer power
      check(
        invertEquation(
          Pow(x - IntegerNumber.one, IntegerNumber.of(3)),
          IntegerNumber.of(-8),
          'x',
        ),
      ).isNotNull().deepEquals([IntegerNumber.negativeOne]);

      // Fractional power with even denominator and negative RHS
      check(
        invertEquation(
          Pow(x, FractionNumber.half),
          IntegerNumber.negativeOne,
          'x',
        ),
      ).isNotNull().isEmpty();
      check(
        invertEquation(
          Pow(x, FractionNumber.half),
          const RealNumber(-1.0),
          'x',
        ),
      ).isNotNull().isEmpty();

      // Fractional power with positive RHS
      check(
        invertEquation(
          Pow(x + IntegerNumber.one, FractionNumber.half),
          IntegerNumber.of(3),
          'x',
        ),
      ).isNotNull().deepEquals([IntegerNumber.of(8)]);
      check(
        invertEquation(Pow(x, RationalNumber(3, 2)), IntegerNumber.of(8), 'x'),
      ).isNotNull().deepEquals([IntegerNumber.of(4)]);
    });
  });

  group('Lambert W and transcendental product/sum equations', () {
    test(
      'inverts LambertW directly and solves x*e^x, x*ln(x), x^x, x+ln(x)',
      () {
        const x = Variable('x');
        // Direct LambertW inversion
        check((LambertW(x, branch: 0) + IntegerNumber.two).solve('x'))
            .isEmpty();
        check((LambertW(x, branch: -1) - IntegerNumber.zero).solve('x'))
            .isEmpty();
        check((LambertW(x, branch: 0) - IntegerNumber.one).solve('x'))
            .deepEquals([Constant.e]);

        // x * e^x = c in all regions: c < -1/e, c == -1/e, -1/e < c < 0, c >= 0, symbolic
        check(Expr.parse('x * exp(x) + 1').solve('x')).isEmpty();
        check(
          (x * Pow(Constant.e, x) + const RealNumber(1.0 / math.e)).solve('x'),
        ).deepEquals([IntegerNumber.negativeOne]);
        final twoBranch = Expr.parse('x * exp(x) + 1/4').solve('x');
        check(twoBranch.length).equals(2);
        final symBranch = Expr.parse('x * exp(x) - a').solve('x');
        check(symBranch.length).equals(2);

        // e^(2*x) * x = c (expFactor on left)
        final leftExp = invertEquation(
          Mul([Pow(Constant.e, IntegerNumber.two * x), x]),
          IntegerNumber.one,
          'x',
        );
        check(leftExp).isNotNull().isNotEmpty();

        // x * ln(x) = c and ln(x) * x = c
        final xLnX = Expr.parse('x * ln(x) - 2').solve('x');
        check(xLnX.length).equals(1);
        final rLn = xLnX.first.evaluate();
        check(rLn * math.log(rLn)).isCloseTo(2.0, 1e-12);

        final lnXX = invertEquation(Mul([Ln(x), x]), IntegerNumber.two, 'x');
        check(lnXX).isNotNull().isNotEmpty();

        // Self-exponentiation: x^x = c
        check(Expr.parse('x^x + 1').solve('x')).isEmpty();
        final xxRoots = Expr.parse('x^x - 4').solve('x');
        check(xxRoots.length).equals(1);
        check(xxRoots.first.evaluate()).isCloseTo(2.0, 1e-12);

        // Additive transcendental: ln(x) + x = c and x + ln(x) = c
        final addLn1 = Expr.parse('ln(x) + x - 1 - pi').solve('x');
        check(addLn1.length).equals(1);
        final rAdd = addLn1.first.evaluate();
        check(math.log(rAdd) + rAdd).isCloseTo(1.0 + math.pi, 1e-12);

        final addLn2 = invertEquation(Add([x, Ln(x)]), IntegerNumber.one, 'x');
        check(addLn2).isNotNull().deepEquals([IntegerNumber.one]);
      },
    );

    test(
      'solves affine exponential equations a^(alpha*x + beta) + k*x + c = 0',
      () {
        const x = Variable('x');
        // e^x - x - 2 = 0 (wVal < 0 -> 2 real roots)
        final twoRoots = Expr.parse('exp(x) - x - 2').solve('x');
        check(twoRoots.length).equals(2);
        for (final r in twoRoots) {
          final v = r.evaluate();
          check(math.exp(v) - v - 2.0).isCloseTo(0.0, 1e-12);
        }

        // e^x - x - 1 = 0 (wVal == -1/e -> single root x = 0)
        final tangentRoot = Expr.parse('exp(x) - x - 1').solve('x');
        check(tangentRoot).deepEquals([IntegerNumber.zero]);

        // e^x - x + 1 = 0 (wVal < -1/e -> no real roots)
        check(Expr.parse('exp(x) - x + 1').solve('x')).isEmpty();

        // e^x + x - 1 = 0 (wVal > 0 -> single root x = 0)
        final posW = Expr.parse('exp(x) + x - 1').solve('x');
        check(posW.length).equals(1);
        check(posW.first.evaluate()).isCloseTo(0.0, 1e-12);

        // Scaled exponential with single and multiple constant factors
        check(Expr.parse('2 * 3^(x + 1) - 4*x - 5').solve('x')).isEmpty();
        final scaledExp = Expr.parse('3 * a * 2^(2*x + 1) - 4*x - 5')
            .solve('x');
        check(scaledExp.length).equals(2);

        // Non-matching additive expressions return empty
        check((Pow(Constant.e, x * x) + x + IntegerNumber.one).solve('x'))
            .isEmpty();
        check((Sin(x) + Cos(x) - IntegerNumber.one).solve('x')).isEmpty();
      },
    );

    test(
      'handles quotient and multi-factor decomposition in invertEquation',
      () {
        const x = Variable('x');
        const a = Variable('a');
        const b = Variable('b');

        // N(x) / const = c
        final r1 = invertEquation(Sin(x) / a, IntegerNumber.zero, 'x');
        check(r1)
            .isNotNull()
            .unorderedEquals([IntegerNumber.zero, Constant.pi]);

        // const / D(x) = c
        check(invertEquation(a / Sin(x), IntegerNumber.zero, 'x'))
            .isNotNull()
            .isEmpty();
        final r2 = invertEquation(a / Sin(x), IntegerNumber.two, 'x');
        check(r2).isNotNull().length.equals(2);

        // N(x) / D(x) = c where D(x) has a pole at one candidate root
        final r3 = invertEquation(
          (x * x - IntegerNumber.one) / (x - IntegerNumber.one),
          IntegerNumber.two,
          'x',
        );
        check(r3).isNotNull().isEmpty();

        // Mul with multiple constant and variable factors
        final r4 = invertEquation(
          Mul([a, b, x, Pow(Constant.e, x)]),
          IntegerNumber.zero,
          'x',
        );
        check(r4).isNotNull().deepEquals([IntegerNumber.zero]);
      },
    );
  });
}
