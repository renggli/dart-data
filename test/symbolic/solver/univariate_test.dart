import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/univariate.dart';
import 'package:data/src/symbolic/type/expr_data_type.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Univariate algebraic and polynomial equations', () {
    test(
      'solves Equal nodes, linear, quadratic, biquadratic, and cubic equations',
      () {
        const x = Variable('x');
        check(
          Relational.equal(
            IntegerNumber.of(3) * x,
            IntegerNumber.of(6),
          ).solve('x'),
        ).deepEquals([IntegerNumber.two]);
        check(IntegerNumber.of(5).solve('x')).isEmpty;

        final quad = Expr.parse('x^2 - 5*x + 6').solve('x');
        check(quad).unorderedEquals([IntegerNumber.two, IntegerNumber.of(3)]);

        final complexQuad = Expr.parse('x^2 + 1').solve('x');
        check(complexQuad).unorderedEquals([-ComplexNumber.i, ComplexNumber.i]);

        final biquad = Expr.parse('x^4 - 5*x^2 + 4').solve('x');
        check(biquad).unorderedEquals([
          IntegerNumber.of(-2),
          IntegerNumber.negativeOne,
          IntegerNumber.one,
          IntegerNumber.two,
        ]);

        // Reducible biquadratics factor first into clean quadratic roots
        final sophieGermain = Expr.parse('x^4 + 4').solve('x');
        check(sophieGermain).unorderedEquals([
          IntegerNumber.one + ComplexNumber.i,
          IntegerNumber.one - ComplexNumber.i,
          IntegerNumber.negativeOne + ComplexNumber.i,
          IntegerNumber.negativeOne - ComplexNumber.i,
        ]);

        final cycloQuartic = Expr.parse('x^4 + x^2 + 1').solve('x');
        check(cycloQuartic.length).equals(4);
        check(cycloQuartic.any((r) => r.format().contains('sqrt(3 * i)')))
            .isFalse;

        // Irreducible biquadratic falls back to biquadratic formula
        final irreducibleBiquad = Expr.parse('x^4 - 4*x^2 + 1').solve('x');
        check(irreducibleBiquad.length).equals(4);

        final cubic = Expr.parse('x^3 - 6*x^2 + 11*x - 6').solve('x');
        check(cubic).unorderedEquals([
          IntegerNumber.one,
          IntegerNumber.two,
          IntegerNumber.of(3),
        ]);

        // Repeated cubic factor: x^3 + 3*x^2 + 3*x + 1 = (x + 1)^3
        final repeatedCubic = Expr.parse('x^3 + 3*x^2 + 3*x + 1').solve('x');
        check(repeatedCubic).deepEquals([IntegerNumber.negativeOne]);

        // Already-factored product with multiplicity
        final factoredProd =
            ((x - IntegerNumber.one) *
                    Pow.of(x - IntegerNumber.two, IntegerNumber.two))
                .solve('x');
        check(factoredProd)
            .unorderedEquals([IntegerNumber.one, IntegerNumber.two]);
      },
    );

    test('solves rational equations and filters denominator poles', () {
      const x = Variable('x');
      check(Expr.parse('1 / (x - 1)').solve('x')).isEmpty;

      final rat = Expr.parse('(x^2 - 1) / (x^2 - 3*x + 2)').solve('x');
      check(rat).deepEquals([IntegerNumber.negativeOne]);

      // Product factor roots that make co-factors undefined or poles are filtered:
      check((x * (IntegerNumber.one / x)).solve('x')).isEmpty;
      check(
        ((x - IntegerNumber.two) *
                (IntegerNumber.one / (x - IntegerNumber.two)))
            .solve('x'),
      ).isEmpty;
      check(
        ((x - IntegerNumber.one) *
                (x - IntegerNumber.two) *
                (IntegerNumber.one / (x - IntegerNumber.two)))
            .solve('x'),
      ).deepEquals([IntegerNumber.one]);
    });

    test('solves exponential, logarithmic, and Lambert W equations', () {
      final expRoots = Expr.parse('exp(2*x) - 5').solve('x');
      check(expRoots.length).equals(1);
      check(expRoots.first.evaluate()).isCloseTo(math.log(5.0) / 2.0, 1e-12);

      final lnRoots = Expr.parse('ln(x + 1) - 2').solve('x');
      check(lnRoots.length).equals(1);
      check(lnRoots.first.evaluate()).isCloseTo(math.exp(2.0) - 1.0, 1e-12);

      final lambertRoots = Expr.parse('x * exp(x) - 2').solve('x');
      check(lambertRoots).isNotEmpty;
      final r = lambertRoots.first.evaluate();
      check(r * math.exp(r)).isCloseTo(2.0, 1e-12);
    });
  });

  group('Domain filtering and root deduplication', () {
    test('filters roots according to VariableDomain assumptions', () {
      const intAssumptions = Assumptions(defaultDomain: VariableDomain.integer);
      final imagEq = Expr.parse('x^2 + 1');
      check(imagEq.solve('x', assumptions: Assumptions.real)).isEmpty;
      check(imagEq.solve('x', assumptions: Assumptions.complex).length)
          .equals(2);

      final posEq = Expr.parse('x^2 - 4');
      check(posEq.solve('x', assumptions: Assumptions.positive))
          .deepEquals([IntegerNumber.two]);

      final ratEq = Expr.parse('(2*x - 3) * (x + 4)');
      check(ratEq.solve('x', assumptions: intAssumptions))
          .deepEquals([IntegerNumber.of(-4)]);
      check(ratEq.solve('x', assumptions: Assumptions.positive))
          .deepEquals([RationalNumber(3, 2)]);

      // Radical and RealNumber roots under real and positive domains
      final radEq = Expr.parse('x^2 - 2');
      check(radEq.solve('x', assumptions: Assumptions.real).length).equals(2);
      check(radEq.solve('x', assumptions: Assumptions.positive).length)
          .equals(1);
      check(
        radEq.solve('x', assumptions: Assumptions.positive).first.evaluate(),
      ).isCloseTo(math.sqrt2, 1e-12);

      final realNumEq = Expr.parse('x - 1.5');
      check(realNumEq.solve('x', assumptions: Assumptions.positive))
          .deepEquals([const RealNumber(1.5)]);

      // Symbolic roots under real and positive domains
      final symEq = Expr.parse('x - a');
      check(symEq.solve('x', assumptions: Assumptions.real))
          .deepEquals([const Variable('a')]);
      check(
        symEq.solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.positive},
          ),
        ),
      ).isEmpty;
      check(symEq.solve('x', assumptions: Assumptions.positive))
          .deepEquals([const Variable('a')]);

      final symQuad = Expr.parse('x^2 - a');
      const posA = Assumptions(
        domains: {'x': VariableDomain.real, 'a': VariableDomain.positive},
      );
      final symRoots = symQuad.solve('x', assumptions: posA);
      check(symRoots.length).equals(2);
      check(symRoots).unorderedEquals([
        -Pow.of(const Variable('a'), FractionNumber.half),
        Pow.of(const Variable('a'), FractionNumber.half),
      ]);
      check(imagEq.solve('x', assumptions: Assumptions.positive)).isEmpty;
    });

    test(
      'isZeroExpr and deduplicateRoots handle numeric and symbolic constants',
      () {
        check(isZeroExpr(IntegerNumber.zero)).isTrue;
        check(isZeroExpr(const RealNumber(0.0))).isTrue;
        check(isZeroExpr(const RealNumber(1e-12))).isFalse;
        check(isZeroExpr(Fn.sin(Constant.pi))).isTrue;
        check(isZeroExpr(Constant.pi)).isFalse;

        final dedup = deduplicateRoots([
          IntegerNumber.one,
          const RealNumber(1.0),
          Fn.sin(Constant.pi),
          IntegerNumber.zero,
        ]);
        check(dedup.length).equals(2);

        // Trigonometric equations with RealNumber RHS
        final sinReal = Expr.parse('sin(x) - 0.5').solve('x');
        check(sinReal).isNotEmpty;
        check(sinReal.first).isA<RealNumber>();

        final cosReal = Expr.parse('cos(x) - 0.5').solve('x');
        check(cosReal).isNotEmpty;
        check(cosReal.first).isA<RealNumber>();

        final tanReal = Expr.parse('tan(x) - 1.5').solve('x');
        check(tanReal).isNotEmpty;
        check(tanReal.first).isA<RealNumber>();

        final posReal = (const Variable('x') - const RealNumber(2.5)).solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.positive},
          ),
        );
        check(posReal).deepEquals([const RealNumber(2.5)]);
      },
    );

    test('filters extraneous roots and solves radical, log, and ln(x)/x', () {
      check(Expr.parse('sqrt(x + 2) - x').solve('x'))
          .deepEquals([IntegerNumber.two]);
      check(Expr.parse('sqrt(x) + 1').solve('x')).isEmpty;
      check(Expr.parse('ln(x - 1) + ln(x + 1) - ln(3)').solve('x'))
          .deepEquals([IntegerNumber.two]);
      final lnOverXEq = Expr.parse('ln(x)/x - 1/(2*e)');
      final lnOverX = lnOverXEq.solve('x');
      check(lnOverX.length).equals(2);
      for (final root in lnOverX) {
        check(lnOverXEq.evaluate({'x': root.evaluate()})).isCloseTo(0.0, 1e-12);
      }

      // Parametric extraneous root rejection under positive assumptions
      check(
        Expr.parse('sqrt(x) + a').solve('x', assumptions: Assumptions.positive),
      ).isEmpty;

      // Symbolic integer root under integer domain assumptions
      final intRoots = Expr.parse('x - (n + 1)').solve(
        'x',
        assumptions: const Assumptions(
          domains: {'x': VariableDomain.integer, 'n': VariableDomain.integer},
        ),
      );
      check(intRoots.length).equals(1);
      check(intRoots.single.expand()).equals(Expr.parse('1 + n').simplify());

      // Distinct exact rationals closer than 1e-12 are preserved
      final closeRat = RationalNumber.of(
        BigInt.parse('1000000000000001'),
        BigInt.parse('1000000000000000'),
      );
      final closeRoots =
          ((const Variable('x') - IntegerNumber.one) *
                  (const Variable('x') - closeRat))
              .solve('x');
      check(closeRoots).unorderedEquals([IntegerNumber.one, closeRat]);
    });

    test('solves binomial equations with non-negative integer second arg', () {
      final roots = Expr.parse('binomial(x, 3)').solve('x');
      check(roots).unorderedEquals([
        IntegerNumber.zero,
        IntegerNumber.one,
        IntegerNumber.two,
      ]);
    });

    test('solves sums of rational functions via together and cancel', () {
      final roots = Expr.parse('1 / (x - 1) + 1 / (x + 1) - 2 * x / (x^2 + 1)')
          .solve('x');
      check(roots).deepEquals([IntegerNumber.zero]);
    });
  });

  group('Domain validation, floating-point tolerances, and root filtering', () {
    test(
      'accepts integer-valued RealNumber under integer domain assumption',
      () {
        final roots = (const Variable('x') - const RealNumber(2.0)).solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.integer},
          ),
        );
        check(roots).deepEquals([const RealNumber(2.0)]);

        final nonInt = (const Variable('x') - const RealNumber(2.5)).solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.integer},
          ),
        );
        check(nonInt).isEmpty;
      },
    );

    test(
      'excludes non-real branch roots like sqrt(-a) under positive assumption',
      () {
        const x = Variable('x');
        const a = Variable('a');
        final roots = (Pow.of(x, IntegerNumber.two) + a).solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.real, 'a': VariableDomain.positive},
          ),
        );
        check(roots).isEmpty;
      },
    );

    test('deduplicateRoots uses relative tolerance for RealNumber only', () {
      const r1 = RealNumber(1000000.0);
      const r2 = RealNumber(1000000.0 + 1e-9);
      check(deduplicateRoots([r1, r2]).length).equals(1);

      // Symbolic vs numeric approximation within 1e-12 is preserved when exact is present
      final s2 = Pow.of(IntegerNumber.two, FractionNumber.half).simplify();
      const s2Approx = RealNumber(1.4142135623730951);
      check(deduplicateRoots([s2, s2Approx]).length).equals(1);

      final bigRational = RationalNumber(1, 1000000000000);
      final quadFloat = Expr.parse('1000000.0 * x - 1000000.0').solve('x');
      check(quadFloat).deepEquals([const RealNumber(1.0)]);
      check(
        satisfiesVariableDomain(
          bigRational,
          VariableDomain.integer,
          Assumptions.none,
        ),
      ).isFalse;
    });

    test('biquadratic equation forwards assumptions', () {
      const a = Variable('a');
      final roots =
          (Pow.of(const Variable('x'), IntegerNumber.of(4)) -
                  a * Pow.of(const Variable('x'), IntegerNumber.two))
              .solve(
                'x',
                assumptions: const Assumptions(
                  domains: {'a': VariableDomain.positive},
                ),
              );
      check(roots.length).equals(3);
    });

    test('filters non-real branch roots and validates large-scale float polynomials', () {
      const a = Variable('a');
      const x = Variable('x');
      const realAssump = Assumptions(
        domains: {'x': VariableDomain.real, 'a': VariableDomain.positive},
      );
      check(
        (Pow.of(x, IntegerNumber.two) + a).solve('x', assumptions: realAssump),
      ).isEmpty;
      final largeRoots =
          (const RealNumber(1000000.0) * Pow.of(x, IntegerNumber.two) -
                  const RealNumber(1000000.0))
              .solve('x');
      check(largeRoots.length).equals(2);

      final boundedAssump = Assumptions.none.withBounds(
        'x',
        lower: IntegerNumber.zero,
        lowerInclusive: true,
        upper: IntegerNumber.two,
        upperInclusive: false,
      );
      check(
        Expr.parse('x * (x - 1) * (x - 2) * (x + 3)')
            .solve('x', assumptions: boundedAssump),
      ).deepEquals([IntegerNumber.zero, IntegerNumber.one]);

      // Transcendental verification on complex roots and unsolvable domains
      check(Expr.parse('sqrt(x) + 1').solve('x', assumptions: Assumptions.real))
          .isEmpty;
      final expComplex = Expr.parse('exp(x) - (1 + i)').solve(
        'x',
        assumptions: const Assumptions(domains: {'x': VariableDomain.complex}),
      );
      check(expComplex.length).equals(1);
    });
  });
}
