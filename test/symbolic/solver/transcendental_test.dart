import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/transcendental.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Inverse trigonometric and hyperbolic equations', () {
    test('solves Asin, Acos, and Atan equations and checks range bounds', () {
      check(Expr.parse('asin(x) - pi/6').solve('x').first.evaluate())
          .isCloseTo(0.5, 1e-12);
      check(Expr.parse('asin(x) - 2').solve('x')).isEmpty;

      check(Expr.parse('acos(x) - pi/3').solve('x').first.evaluate())
          .isCloseTo(0.5, 1e-12);
      check(Expr.parse('acos(x) + 1').solve('x')).isEmpty;
      check(Expr.parse('acos(x) - 4').solve('x')).isEmpty;

      check(Expr.parse('atan(x) - pi/4').solve('x').first.evaluate())
          .isCloseTo(1.0, 1e-12);
      check(Expr.parse('atan(x) - 2').solve('x')).isEmpty;
      check(Expr.parse('atan(x) + 2').solve('x')).isEmpty;
    });

    test('solves Sinh, Cosh, Tanh, Asinh, Acosh, Atanh, Abs, and Erf', () {
      const x = Variable('x');
      check(Fn.sinh(x).solve('x')).deepEquals([IntegerNumber.zero]);
      check((Fn.sinh(x) - IntegerNumber.two).solve('x'))
          .deepEquals([Fn.asinh(IntegerNumber.two)]);

      check((Fn.cosh(x) - FractionNumber.half).solve('x')).isEmpty;
      check((Fn.cosh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([IntegerNumber.zero]);
      check((Fn.cosh(x) - IntegerNumber.two).solve('x')).unorderedEquals([
        Fn.acosh(IntegerNumber.two),
        (-Fn.acosh(IntegerNumber.two)).simplify(),
      ]);

      check((Fn.tanh(x) - IntegerNumber.one).solve('x')).isEmpty;
      check((Fn.tanh(x) + IntegerNumber.two).solve('x')).isEmpty;
      check((Fn.tanh(x) - FractionNumber.half).solve('x'))
          .deepEquals([Fn.atanh(FractionNumber.half)]);

      check((Fn.asinh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([Fn.sinh(IntegerNumber.one)]);

      check((Fn.acosh(x) + IntegerNumber.one).solve('x')).isEmpty;
      check((Fn.acosh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([Fn.cosh(IntegerNumber.one)]);

      check((Fn.atanh(x) - IntegerNumber.one).solve('x'))
          .deepEquals([Fn.tanh(IntegerNumber.one)]);

      check((Fn.abs(x) + IntegerNumber.one).solve('x')).isEmpty;
      check(Fn.abs(x - IntegerNumber.of(3)).solve('x'))
          .deepEquals([IntegerNumber.of(3)]);
      check((Fn.abs(x - IntegerNumber.one) - IntegerNumber.two).solve('x'))
          .unorderedEquals([IntegerNumber.negativeOne, IntegerNumber.of(3)]);

      check(Fn.erf(x - IntegerNumber.two).solve('x'))
          .deepEquals([IntegerNumber.two]);
      check((Fn.erf(x) - IntegerNumber.two).solve('x')).isEmpty;
      check((Fn.erf(x) - FractionNumber.half).solve('x')).isEmpty;
    });
  });

  group('Exponential, power, and radical equations', () {
    test('solves e^f(x) = c and b^f(x) = c', () {
      check(Expr.parse('exp(x) + 1').solve('x')).isEmpty;
      check(Expr.parse('exp(2*x) - 1').solve('x'))
          .deepEquals([IntegerNumber.zero]);

      check(Expr.parse('2^x + 1').solve('x')).isEmpty;
      final twoPow = Expr.parse('2^x - 8').solve('x');
      check(twoPow.length).equals(1);
      check(twoPow.first.evaluate()).isCloseTo(3.0, 1e-12);

      // Symbolic base
      final symPow = Expr.parse('a^x - b').solve('x');
      check(symPow).deepEquals([
        (Fn.ln(const Variable('b')) / Fn.ln(const Variable('a'))).simplify(),
      ]);
    });

    test('solves even, odd, negative, and fractional power equations', () {
      const x = Variable('x');
      // Negative power equal to 0 has no solution
      check(
        invertEquation(
          Pow.of(x + IntegerNumber.one, IntegerNumber.of(-2)),
          IntegerNumber.zero,
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().isEmpty;

      // Even integer power
      check(
        invertEquation(
          Pow.of(x + IntegerNumber.one, IntegerNumber.two),
          IntegerNumber.of(-4),
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().isEmpty;
      check(
        invertEquation(
          Pow.of(x + IntegerNumber.one, IntegerNumber.two),
          const RealNumber(-4.0),
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().isEmpty;
      check(
            invertEquation(
              Pow.of(x - IntegerNumber.one, IntegerNumber.two),
              IntegerNumber.of(9),
              'x',
              assumptions: Assumptions.none,
            ),
          )
          .isNotNull()
          .unorderedEquals([IntegerNumber.of(-2), IntegerNumber.of(4)]);

      // Odd integer power
      check(
        invertEquation(
          Pow.of(x - IntegerNumber.one, IntegerNumber.of(3)),
          IntegerNumber.of(-8),
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().deepEquals([IntegerNumber.negativeOne]);

      // Fractional power with even denominator and negative RHS
      check(
        invertEquation(
          Pow.of(x, FractionNumber.half),
          IntegerNumber.negativeOne,
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().isEmpty;
      check(
        invertEquation(
          Pow.of(x, FractionNumber.half),
          const RealNumber(-1.0),
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().isEmpty;

      // Fractional power with positive RHS
      check(
        invertEquation(
          Pow.of(x + IntegerNumber.one, FractionNumber.half),
          IntegerNumber.of(3),
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().deepEquals([IntegerNumber.of(8)]);
      check(
        invertEquation(
          Pow.of(x, RationalNumber(3, 2)),
          IntegerNumber.of(8),
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().deepEquals([IntegerNumber.of(4)]);

      // Negative even integer power: x^(-2) = 4 -> x = ±1/2
      check(
            invertEquation(
              Pow.of(x, IntegerNumber.of(-2)),
              IntegerNumber.of(4),
              'x',
              assumptions: Assumptions.none,
            ),
          )
          .isNotNull()
          .unorderedEquals([FractionNumber.half, FractionNumber.negativeHalf]);

      // Rational power with even numerator: x^(2/3) = 4 -> x = ±8
      check(
            invertEquation(
              Pow.of(x, RationalNumber(2, 3)),
              IntegerNumber.of(4),
              'x',
              assumptions: Assumptions.none,
            ),
          )
          .isNotNull()
          .unorderedEquals([IntegerNumber.of(8), IntegerNumber.of(-8)]);

      // Even power equal to negative symbolic constant (-pi) has no real root
      check(
        invertEquation(
          Pow.of(x, IntegerNumber.two),
          -Constant.pi,
          'x',
          assumptions: Assumptions.none,
        ),
      ).isNotNull().isEmpty;
    });
  });

  group('Lambert W and transcendental product/sum equations', () {
    test(
      'inverts LambertW directly and solves x*e^x, x*ln(x), x^x, x+ln(x)',
      () {
        const x = Variable('x');
        // Direct LambertW inversion
        check((Fn.lambertW(x) + IntegerNumber.two).solve('x')).isEmpty;
        check(
          (Fn.lambertW(x, IntegerNumber.negativeOne) - IntegerNumber.zero)
              .solve('x'),
        ).isEmpty;
        check((Fn.lambertW(x) - IntegerNumber.one).solve('x'))
            .deepEquals([Constant.e]);

        // x * e^x = c in all regions: c < -1/e, c == -1/e, -1/e < c < 0, c >= 0, symbolic
        check(Expr.parse('x * exp(x) + 1').solve('x')).isEmpty;
        check(
          (x * Pow.of(Constant.e, x) +
                  Pow.of(Constant.e, IntegerNumber.negativeOne))
              .solve('x'),
        ).deepEquals([IntegerNumber.negativeOne]);
        check(
          (x * Pow.of(Constant.e, x) + const RealNumber(1.0 / math.e)).solve(
            'x',
          ),
        ).deepEquals([const RealNumber(-1.0)]);
        final twoBranch = Expr.parse('x * exp(x) + 1/4').solve('x');
        check(twoBranch.length).equals(2);
        final symBranch = Expr.parse('x * exp(x) - a').solve('x');
        check(symBranch.length).equals(2);

        // e^(2*x) * x = c (expFactor on left)
        final leftExp = invertEquation(
          Mul.of([Pow.of(Constant.e, IntegerNumber.two * x), x]),
          IntegerNumber.one,
          'x',
          assumptions: Assumptions.none,
        );
        check(leftExp).isNotNull().isNotEmpty;

        // x * ln(x) = c and ln(x) * x = c
        final xLnX = Expr.parse('x * ln(x) - 2').solve('x');
        check(xLnX.length).equals(1);
        final rLn = xLnX.first.evaluate();
        check(rLn * math.log(rLn)).isCloseTo(2.0, 1e-12);

        final lnXX = invertEquation(
          Mul.of([Fn.ln(x), x]),
          IntegerNumber.two,
          'x',
          assumptions: Assumptions.none,
        );
        check(lnXX).isNotNull().isNotEmpty;

        // Self-exponentiation: x^x = c
        check(Expr.parse('x^x + 1').solve('x')).isEmpty;
        final xxRoots = Expr.parse('x^x - 4').solve('x');
        check(xxRoots.length).equals(1);
        check(xxRoots.first.evaluate()).isCloseTo(2.0, 1e-12);

        // Additive transcendental: ln(x) + x = c and x + ln(x) = c
        final addLn1 = Expr.parse('ln(x) + x - 1 - pi').solve('x');
        check(addLn1.length).equals(1);
        final rAdd = addLn1.first.evaluate();
        check(math.log(rAdd) + rAdd).isCloseTo(1.0 + math.pi, 1e-12);

        final addLn2 = invertEquation(
          Add.of([x, Fn.ln(x)]),
          IntegerNumber.one,
          'x',
          assumptions: Assumptions.none,
        );
        check(addLn2).isNotNull().deepEquals([IntegerNumber.one]);

        // Non-unit Lambert W ratios in product and sum:
        final nonUnitMul =
            (x * Fn.ln(IntegerNumber.two * x) - IntegerNumber.two).solve('x');
        check(nonUnitMul.length).equals(1);
        final rNonUnitMul = nonUnitMul.first.evaluate();
        check(rNonUnitMul * math.log(2.0 * rNonUnitMul)).isCloseTo(2.0, 1e-12);

        final nonUnitAdd1 =
            (Fn.ln(IntegerNumber.two * x) + x - IntegerNumber.of(3)).solve('x');
        check(nonUnitAdd1.length).equals(1);
        final rNonUnitAdd1 = nonUnitAdd1.first.evaluate();
        check(math.log(2.0 * rNonUnitAdd1) + rNonUnitAdd1)
            .isCloseTo(3.0, 1e-12);

        final nonUnitAdd2 =
            (Fn.ln(x) + IntegerNumber.two * x - IntegerNumber.of(3)).solve('x');
        check(nonUnitAdd2.length).equals(1);
        final rNonUnitAdd2 = nonUnitAdd2.first.evaluate();
        check(math.log(rNonUnitAdd2) + 2.0 * rNonUnitAdd2)
            .isCloseTo(3.0, 1e-12);
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
        check(Expr.parse('exp(x) - x + 1').solve('x')).isEmpty;

        // e^x + x - 1 = 0 (wVal > 0 -> single root x = 0)
        final posW = Expr.parse('exp(x) + x - 1').solve('x');
        check(posW.length).equals(1);
        check(posW.first.evaluate()).isCloseTo(0.0, 1e-12);

        // Scaled exponential with single and multiple constant factors
        check(Expr.parse('2 * 3^(x + 1) - 4*x - 5').solve('x')).isEmpty;
        final scaledExp = Expr.parse('3 * a * 2^(2*x + 1) - 4*x - 5')
            .solve('x');
        check(scaledExp.length).equals(2);

        // Non-matching additive expressions return empty
        check((Pow.of(Constant.e, x * x) + x + IntegerNumber.one).solve('x'))
            .isEmpty;

        // Exponential form e^exponent = c forwards assumptions
        check(
          (Pow.of(Constant.e, x * x) - Constant.e).solve(
            'x',
            assumptions: Assumptions.positive,
          ),
        ).deepEquals([IntegerNumber.one]);
      },
    );

    test(
      'handles quotient and multi-factor decomposition in invertEquation',
      () {
        const x = Variable('x');
        const a = Variable('a');
        const b = Variable('b');

        // N(x) / const = c
        final r1 = invertEquation(
          Fn.sin(x) / a,
          IntegerNumber.zero,
          'x',
          assumptions: Assumptions.none,
        );
        check(r1)
            .isNotNull()
            .unorderedEquals([IntegerNumber.zero, Constant.pi]);

        // const / D(x) = c
        check(
          invertEquation(
            a / Fn.sin(x),
            IntegerNumber.zero,
            'x',
            assumptions: Assumptions.none,
          ),
        ).isNotNull().isEmpty;
        final r2 = invertEquation(
          a / Fn.sin(x),
          IntegerNumber.two,
          'x',
          assumptions: Assumptions.none,
        );
        check(r2).isNotNull().length.equals(2);

        // N(x) / D(x) = c where D(x) has a pole at one candidate root
        final r3 = invertEquation(
          (x * x - IntegerNumber.one) / (x - IntegerNumber.one),
          IntegerNumber.two,
          'x',
          assumptions: Assumptions.none,
        );
        check(r3).isNotNull().isEmpty;

        // Mul with multiple constant and variable factors
        final r4 = invertEquation(
          Mul.of([a, b, x, Pow.of(Constant.e, x)]),
          IntegerNumber.zero,
          'x',
          assumptions: Assumptions.none,
        );
        check(r4).isNotNull().deepEquals([IntegerNumber.zero]);

        // Product transcendental: ln(x)/x = 1/(2*e) -> exp(-W_k(-1/(2*e)))
        final r5 = invertEquation(
          Mul.of([Pow.of(x, IntegerNumber.negativeOne), Fn.ln(x)]),
          (IntegerNumber.one / (IntegerNumber.two * Constant.e)).simplify(),
          'x',
          assumptions: Assumptions.none,
        );
        check(r5).isNotNull().length.equals(2);
        for (final root in r5!) {
          check(
            (Fn.ln(root) / root -
                    IntegerNumber.one / (IntegerNumber.two * Constant.e))
                .evaluate(),
          ).isCloseTo(0.0, 1e-12);
        }
      },
    );

    test('solves polynomial equations in exponential substitutions', () {
      check(Expr.parse('exp(2*x) - 3*exp(x) + 2').solve('x'))
          .unorderedEquals([IntegerNumber.zero, Fn.ln(IntegerNumber.two)]);
      check(Expr.parse('exp(2*x) - 1').solve('x'))
          .deepEquals([IntegerNumber.zero]);
    });

    test('solves polynomial equations in elementary functions', () {
      check(Expr.parse('ln(x)^2 - 3*ln(x) + 2').solve('x'))
          .unorderedEquals([Constant.e, Pow.of(Constant.e, IntegerNumber.two)]);
      check(Expr.parse('2*sin(x)^2 - 3*sin(x) + 1').solve('x')).unorderedEquals(
        [
          (Constant.pi / IntegerNumber.of(6)).simplify(),
          (Constant.pi / IntegerNumber.two).simplify(),
          (IntegerNumber.of(5) * Constant.pi / IntegerNumber.of(6)).simplify(),
        ],
      );
      final sinhRoots = Expr.parse('sinh(x)^2 - 3*sinh(x) + 2').solve('x');
      check(sinhRoots.length).equals(2);
      for (final root in sinhRoots) {
        final v = root.evaluate();
        check(
          math.pow((math.exp(v) - math.exp(-v)) / 2, 2) -
              3 * ((math.exp(v) - math.exp(-v)) / 2) +
              2,
        ).isCloseTo(0.0, 1e-12);
      }
    });

    test('solves multiple-angle trigonometric equations', () {
      check(Expr.parse('cos(2*x) - cos(x)').solve('x')).unorderedEquals([
        IntegerNumber.zero,
        (IntegerNumber.two * Constant.pi / IntegerNumber.of(3)).simplify(),
        (IntegerNumber.of(4) * Constant.pi / IntegerNumber.of(3)).simplify(),
      ]);
      check(Expr.parse('sin(2*x) - sin(x)').solve('x')).unorderedEquals([
        IntegerNumber.zero,
        Constant.pi,
        (Constant.pi / IntegerNumber.of(3)).simplify(),
        (IntegerNumber.of(5) * Constant.pi / IntegerNumber.of(3)).simplify(),
      ]);
    });

    test('solves harmonic addition equations a*sin(u) + b*cos(u) + k = 0', () {
      check(Expr.parse('sin(x) + cos(x) - 1').solve('x')).unorderedEquals([
        IntegerNumber.zero,
        (Constant.pi / IntegerNumber.two).simplify(),
      ]);
      check(Expr.parse('sin(x) - cos(x)').solve('x')).unorderedEquals([
        (Constant.pi / IntegerNumber.of(4)).simplify(),
        (IntegerNumber.of(5) * Constant.pi / IntegerNumber.of(4)).simplify(),
      ]);
      check(Expr.parse('sin(x) + cos(x) - 3').solve('x')).isEmpty;
    });
  });

  group('Transcendental solver edge cases', () {
    test(
      'solves mixed-sign exponential polynomials like exp(x) + exp(-x) = 3',
      () {
        final roots = Expr.parse('exp(x) + exp(-x) - 3').solve('x');
        check(roots.length).equals(2);
        for (final r in roots) {
          final v = r.evaluate();
          check(math.exp(v) + math.exp(-v) - 3.0).isCloseTo(0.0, 1e-12);
        }
      },
    );

    test('handles negativeRealNumber odd rational powers on real domain', () {
      const realX = Assumptions(domains: {'x': VariableDomain.real});
      final invCube =
          (Pow.of(const Variable('x'), IntegerNumber.of(-3)) +
                  const RealNumber(0.125))
              .solve('x', assumptions: realX);
      check(invCube).deepEquals([const RealNumber(-2.0)]);

      final invFifth =
          (Pow.of(const Variable('x'), IntegerNumber.of(-5)) +
                  const RealNumber(0.03125))
              .solve('x', assumptions: realX);
      check(invFifth).deepEquals([const RealNumber(-2.0)]);
    });

    test('guards harmonic addition against complex or degenerate r == 0 coefficients', () {
      const x = Variable('x');
      final degenerate =
          Fn.sin(x) + ComplexNumber.i * Fn.cos(x) - IntegerNumber.one;
      check(degenerate.solve('x')).isEmpty;
      final negA = Expr.parse('-3 * sin(x) - 4 * cos(x) + 5').solve('x');
      check(negA.length).equals(1);
    });

    test(
      'guards affine exponential bases and log combination negative args',
      () {
        const a = Variable('a');
        const posA = Assumptions(domains: {'a': VariableDomain.positive});
        check(Expr.parse('1^x + x - 2').solve('x'))
            .deepEquals([IntegerNumber.one]);
        final comb =
            (Fn.ln(const Variable('x') - a) + Fn.ln(const Variable('x') + a))
                .solve('x', assumptions: posA);
        // Roots x^2 - a^2 = 1 -> only +sqrt(a^2 + 1) satisfies x - a > 0 under a > 0.
        check(comb.length).equals(1);
      },
    );

    test(
      'solves Ln(x)/x Lambert W branch and scaled/negative radical equations',
      () {
        const x = Variable('x');
        final logDivX = (Fn.ln(x) / x - RationalNumber(1, 10)).solve('x');
        check(logDivX.length).equals(2);

        final scaledRad =
            (IntegerNumber.two *
                        Pow.of(x + IntegerNumber.one, FractionNumber.half) -
                    IntegerNumber.of(6))
                .solve('x');
        check(scaledRad).deepEquals([IntegerNumber.of(8)]);

        final negRad =
            (IntegerNumber.of(3) * Pow.of(x, RationalNumber(-1, 2)) -
                    IntegerNumber.one)
                .solve('x');
        check(negRad).deepEquals([IntegerNumber.of(9)]);
      },
    );
  });
}
