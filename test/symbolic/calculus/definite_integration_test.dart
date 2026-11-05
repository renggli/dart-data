import 'package:checks/checks.dart';
import 'package:data/src/symbolic/calculus/definite_integration.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Definite integration helper utilities', () {
    test('isInfiniteBound identifies infinities', () {
      check(isInfiniteBound(Constant.infinity)).isTrue();
      check(isInfiniteBound(-Constant.infinity)).isTrue();
      check(isInfiniteBound(IntegerNumber.zero)).isFalse();
      check(isInfiniteBound(x)).isFalse();
    });

    test('isPositiveConstant and isNegativeConstant', () {
      check(isPositiveConstant(IntegerNumber.of(5))).isTrue();
      check(isPositiveConstant(FractionNumber.half)).isTrue();
      check(isPositiveConstant(const RealNumber(2.5))).isTrue();
      check(isPositiveConstant(Constant.pi)).isTrue();
      check(isPositiveConstant(IntegerNumber.zero)).isFalse();
      check(isPositiveConstant(IntegerNumber.of(-1))).isFalse();
      check(isPositiveConstant(x)).isFalse();

      check(isNegativeConstant(IntegerNumber.of(-5))).isTrue();
      check(isNegativeConstant(IntegerNumber.of(5))).isFalse();
    });

    test('findDenominatorRoots locates denominator singularities', () {
      final roots1 = findDenominatorRoots(Expr.parse('1 / (x - 3)'), 'x');
      check(roots1).unorderedEquals([3.0]);

      final roots2 = findDenominatorRoots(Expr.parse('1 / (x^2 - 4)'), 'x');
      check(roots2).unorderedEquals([-2.0, 2.0]);
    });

    test('isOddIntegrandWithoutInteriorPoles checks symmetry and poles', () {
      check(
        isOddIntegrandWithoutInteriorPoles(
          Expr.parse('x^3'),
          'x',
          IntegerNumber.of(-1),
          IntegerNumber.one,
        ),
      ).isTrue();

      // Even function is not odd
      check(
        isOddIntegrandWithoutInteriorPoles(
          Expr.parse('x^2'),
          'x',
          IntegerNumber.of(-1),
          IntegerNumber.one,
        ),
      ).isFalse();

      // Odd function with pole in interval
      check(
        isOddIntegrandWithoutInteriorPoles(
          Expr.parse('1 / x'),
          'x',
          IntegerNumber.of(-1),
          IntegerNumber.one,
        ),
      ).isFalse();
    });
  });

  group('Definite integration and bounds handling', () {
    test('validates bounds and handles equal, symbolic, and float bounds', () {
      check(() => x.integrate('x', from: 0)).throws<ArgumentError>();
      check(() => x.integrate('x', to: 1)).throws<ArgumentError>();
      check(x.integrate('x', from: 2, to: 2)).equals(IntegerNumber.zero);

      check(Expr.parse('x^2').integrate('x', from: 0, to: 3))
          .equals(IntegerNumber.of(9));
      check(
        x.integrate(
          'x',
          from: const RealNumber(0.0),
          to: const RealNumber(2.0),
        ),
      ).equals(const RealNumber(2.0));
      check(x.integrate('x', from: 0.0, to: 0.5))
          .equals(const RealNumber(0.125));
      check(x.integrate('x', from: 0.0, to: 0.1234567).evaluate())
          .isCloseTo(0.5 * 0.1234567 * 0.1234567, 1e-12);
      check(x.integrate('x', from: 0.0, to: double.nan).evaluate().isNaN)
          .isTrue();

      final paramDef = (y * x).integrate('x', from: 0, to: 2);
      check(paramDef).equals((IntegerNumber.two * y).simplify());

      final symConstDef = Pow(Constant.e, x).integrate('x', from: 0, to: 1);
      check(symConstDef)
          .equals((IntegerNumber.negativeOne + Constant.e).simplify());

      check(Sin(x).integrate('x', from: 0, to: Constant.pi))
          .equals(IntegerNumber.two);
      check(
        x.integrate('x', from: const Variable('a'), to: const Variable('b')),
      ).equals(
        (FractionNumber.half * Pow(const Variable('b'), IntegerNumber.two) -
                FractionNumber.half *
                    Pow(const Variable('a'), IntegerNumber.two))
            .simplify(),
      );
      check(x.integrate('x', from: BigInt.zero, to: BigInt.two))
          .equals(IntegerNumber.two);
      check(() => x.integrate('x', from: 0, to: '??? invalid'))
          .throws<ArgumentError>();
    });

    test('evaluates improper infinite bounds and unevaluated fallbacks', () {
      final expDecay = Expr.parse('exp(-x)')
          .integrate('x', from: 0, to: double.infinity);
      check(expDecay).equals(IntegerNumber.one);

      final symInfDecay = Expr.parse('exp(-x)')
          .integrate('x', from: 0, to: Constant.infinity);
      check(symInfDecay).equals(IntegerNumber.one);

      final symNegInf = Expr.parse('exp(x)')
          .integrate('x', from: -Constant.infinity, to: 0);
      check(symNegInf).equals(IntegerNumber.one);

      final expGrowthLeft = Expr.parse('exp(x)')
          .integrate('x', from: double.negativeInfinity, to: 0);
      check(expGrowthLeft).equals(IntegerNumber.one);

      final revInfinite = Expr.parse('exp(-x)')
          .integrate('x', from: double.infinity, to: 0);
      check(revInfinite).equals(IntegerNumber.negativeOne);

      final revNegInfinite = Expr.parse('exp(x)')
          .integrate('x', from: 0, to: double.negativeInfinity);
      check(revNegInfinite).equals(IntegerNumber.negativeOne);

      final lorentz = Expr.parse('1 / (1 + x^2)')
          .integrate('x', from: double.negativeInfinity, to: double.infinity);
      check(lorentz).equals(Constant.pi);

      final fresnel = Expr.parse('sin(x^2)').integrate('x', from: 0, to: 1);
      check(fresnel).isA<Integral>();
      check(fresnel.evaluate()).isCloseTo(0.3102683017233811, 1e-12);

      final oscImproper = Cos(x).integrate('x', from: 0, to: double.infinity);
      check(oscImproper).isA<Integral>();

      // Interior singularity pole detection:
      final divergentPole = Expr.parse('1/x^2').integrate('x', from: -1, to: 1);
      check(divergentPole).isA<Integral>();

      final divergentInfPole = Expr.parse('1/x^2')
          .integrate('x', from: -Constant.infinity, to: Constant.infinity);
      check(divergentInfPole).isA<Integral>();

      final divergentSemiInfPole = Expr.parse('1/x^2')
          .integrate('x', from: -1, to: Constant.infinity);
      check(divergentSemiInfPole).isA<Integral>();

      final divergentLeftSemiInfPole = Expr.parse('1/x^2')
          .integrate('x', from: -Constant.infinity, to: 1);
      check(divergentLeftSemiInfPole).isA<Integral>();

      final shiftedPole = Expr.parse('1/(x - 1)^2')
          .integrate('x', from: 0, to: 2);
      check(shiftedPole).isA<Integral>();

      // Interior pole detection for Tan(u) and Ln(u):
      final tanSquarePole = Pow(
        Tan(x),
        IntegerNumber.two,
      ).integrate('x', from: IntegerNumber.zero, to: Constant.pi);
      check(tanSquarePole).isA<Integral>();

      final tanSquareNoPole = Pow(Tan(x), IntegerNumber.two).integrate(
        'x',
        from: IntegerNumber.zero,
        to: (Constant.pi / IntegerNumber.of(4)).simplify(),
      );
      check(tanSquareNoPole).equals(
        (IntegerNumber.one - Constant.pi / IntegerNumber.of(4)).simplify(),
      );

      final lnCrossingZero = Ln(x).integrate('x', from: -1, to: 1);
      check(lnCrossingZero).isA<Integral>();

      // Non-overlapping interval with pole outside [1, 2] evaluates cleanly:
      final outsidePole = Expr.parse('1/x^2').integrate('x', from: 1, to: 2);
      check(outsidePole).equals(RationalNumber(1, 2));

      // Negative bounds for logarithmic antiderivatives:
      final negBoundsLog = Expr.parse('1/x').integrate('x', from: -2, to: -1);
      check(negBoundsLog).equals(-Ln(IntegerNumber.two));

      // Domain assumptions preserved during antiderivative construction:
      const posAssumptions = Assumptions(
        domains: {'x': VariableDomain.positive},
      );
      final sqrtSqInt = Expr.parse('sqrt(x^2)')
          .integrate('x', assumptions: posAssumptions);
      check(sqrtSqInt).equals(FractionNumber.half * Pow(x, IntegerNumber.two));

      final posDefInt = (IntegerNumber.one / x).integrate(
        'x',
        from: 1,
        to: 2,
        assumptions: posAssumptions,
      );
      check(posDefInt).equals(Ln(IntegerNumber.two));
    });
  });

  group('Famous definite and improper integrals', () {
    test('evaluates Gaussian, Dirichlet, Fresnel, Gamma, Bose-Einstein, Euler log-sine, and Wallis integrals', () {
      // Gaussian integrals:
      check(
        Expr.parse('exp(-x^2)')
            .integrate('x', from: -Constant.infinity, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(pi)').simplify());
      check(
        Expr.parse('exp(-x^2)').integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(pi) / 2').simplify());
      check(
        Expr.parse('x^2 * exp(-x^2)')
            .integrate('x', from: -Constant.infinity, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(pi) / 2').simplify());

      // Dirichlet integrals:
      check(
        Expr.parse('sin(x) / x').integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('pi / 2').simplify());
      check(
        Expr.parse('sin(x) / x')
            .integrate('x', from: -Constant.infinity, to: Constant.infinity),
      ).equals(Constant.pi);
      check(
        Expr.parse('sin(x)^2 / x^2')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('pi / 2').simplify());

      // Fresnel integrals:
      check(
        Expr.parse('sin(x^2)').integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(2 * pi) / 4').simplify());
      check(
        Expr.parse('cos(x^2)').integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(2 * pi) / 4').simplify());

      // Gamma and fractional moments:
      check(
        Expr.parse('x^(-1/2) * exp(-x)')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(pi)').simplify());
      check(
        Expr.parse('x^(1/2) * exp(-x)')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('sqrt(pi) / 2').simplify());

      // Bose-Einstein & Fermi-Dirac integrals:
      check(
        Expr.parse('x / (exp(x) - 1)')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('pi^2 / 6').simplify());
      check(
        Expr.parse('x^3 / (exp(x) - 1)')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('pi^4 / 15').simplify());
      check(
        Expr.parse('x / (exp(x) + 1)')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('pi^2 / 12').simplify());

      // Euler log-sine and log-cosine integrals:
      check(
        Expr.parse('ln(sin(x))')
            .integrate('x', from: 0, to: Expr.parse('pi / 2')),
      ).equals(Expr.parse('-pi / 2 * ln(2)').simplify());
      check(
        Expr.parse('ln(cos(x))')
            .integrate('x', from: 0, to: Expr.parse('pi / 2')),
      ).equals(Expr.parse('-pi / 2 * ln(2)').simplify());
      check(Expr.parse('ln(sin(x))').integrate('x', from: 0, to: Constant.pi))
          .equals(Expr.parse('-pi * ln(2)').simplify());

      // Logarithmic unit-interval integrals:
      check(Expr.parse('ln(x)').integrate('x', from: 0, to: 1))
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('ln(x) / (1 - x)').integrate('x', from: 0, to: 1))
          .equals(Expr.parse('-pi^2 / 6').simplify());
      check(Expr.parse('ln(x) / (1 + x)').integrate('x', from: 0, to: 1))
          .equals(Expr.parse('-pi^2 / 12').simplify());
      check(Expr.parse('ln(1 + x) / x').integrate('x', from: 0, to: 1))
          .equals(Expr.parse('pi^2 / 12').simplify());

      // Wallis / Beta integrals on [0, pi/2]:
      check(
        Expr.parse('sin(x)^4 * cos(x)^2')
            .integrate('x', from: 0, to: Expr.parse('pi / 2')),
      ).equals(Expr.parse('pi / 32').simplify());

      // Odd function symmetry on [-a, a]:
      check(
        Expr.parse('x^3 * cos(x) * exp(-x^2)').integrate('x', from: -2, to: 2),
      ).equals(IntegerNumber.zero);

      // Reversed bounds, constant scaling, Euler Beta, and symbolic Gamma on [0, infty)
      check(
        Expr.parse('exp(-x^2)').integrate('x', from: Constant.infinity, to: 0),
      ).equals(Expr.parse('-sqrt(pi) / 2').simplify());
      check(
        Expr.parse('3 * sin(x) / x')
            .integrate('x', from: 0, to: Constant.infinity),
      ).equals(Expr.parse('3 * pi / 2').simplify());
      check(
        Expr.parse('x^s * exp(-a * x)').integrate(
          'x',
          from: 0,
          to: Constant.infinity,
          assumptions: Assumptions.positive,
        ),
      ).equals(Expr.parse('gamma(s + 1) / a^(s + 1)').simplify());
      check(
        Expr.parse('sin(x) * cos(x)')
            .integrate('x', from: 0, to: Expr.parse('pi / 2')),
      ).equals(FractionNumber.half);
      check(Expr.parse('ln(1 - x) / x').integrate('x', from: 0, to: 1))
          .equals(Expr.parse('-pi^2 / 6').simplify());
      check(Expr.parse('x * (1 - x)').integrate('x', from: 0, to: 1))
          .equals(RationalNumber.of(const Integer(1), const Integer(6)));
      check(Expr.parse('x^2 * (1 - x)^3').integrate('x', from: 0, to: 1))
          .equals(RationalNumber.of(const Integer(1), const Integer(60)));

      // Non-elementary Beta/Wallis integrals and odd integrand pole checks
      check(
        Expr.parse('x^(1/2) * (1 - x)^(1/2)').integrate('x', from: 0, to: 1),
      ).equals(Expr.parse('pi / 8').simplify());
      check(Expr.parse('x * (1 - x)^(1/3)').integrate('x', from: 0, to: 1))
          .isNotNull();
      check(Expr.parse('x^(1/3) * (1 - x)').integrate('x', from: 0, to: 1))
          .isNotNull();
      check(
        Expr.parse('sin(x) * cos(x)^(1/2)')
            .integrate('x', from: 0, to: Expr.parse('pi / 2')),
      ).isNotNull();
      check(
        Expr.parse('sin(x)^(1/2) * cos(x)')
            .integrate('x', from: 0, to: Expr.parse('pi / 2')),
      ).isNotNull();
      check(Expr.parse('sin(x^3) / (x^2 - 4)').integrate('x', from: -1, to: 1))
          .equals(IntegerNumber.zero);
      check(Expr.parse('sin(x^3) / x').integrate('x', from: -1, to: 1))
          .isA<Integral>();
      check(
        Expr.parse('sin(x^3) / (x^2 - 4)')
            .integrate('x', from: -Constant.infinity, to: Constant.infinity),
      ).isA<Integral>();
      check(Expr.parse('1 / (x^2 - 2)').integrate('x', from: 0, to: 2))
          .isA<Integral>();
    });
  });
}
