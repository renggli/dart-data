import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Univariate algebraic and polynomial equations', () {
    test(
      'solves Equal nodes, linear, quadratic, biquadratic, and cubic equations',
      () {
        const x = Variable('x');
        check(Equal(IntegerNumber.of(3) * x, IntegerNumber.of(6)).solve('x'))
            .deepEquals([IntegerNumber.two]);
        check(IntegerNumber.of(5).solve('x')).isEmpty();

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
                    Pow(x - IntegerNumber.two, IntegerNumber.two))
                .solve('x');
        check(factoredProd)
            .unorderedEquals([IntegerNumber.one, IntegerNumber.two]);
      },
    );

    test('solves rational equations and filters denominator poles', () {
      check(Expr.parse('1 / (x - 1)').solve('x')).isEmpty();

      final rat = Expr.parse('(x^2 - 1) / (x^2 - 3*x + 2)').solve('x');
      check(rat).deepEquals([IntegerNumber.negativeOne]);
    });

    test('solves exponential, logarithmic, and Lambert W equations', () {
      final expRoots = Expr.parse('exp(2*x) - 5').solve('x');
      check(expRoots.length).equals(1);
      check(expRoots.first.evaluate()).isCloseTo(math.log(5.0) / 2.0, 1e-12);

      final lnRoots = Expr.parse('ln(x + 1) - 2').solve('x');
      check(lnRoots.length).equals(1);
      check(lnRoots.first.evaluate()).isCloseTo(math.exp(2.0) - 1.0, 1e-12);

      final lambertRoots = Expr.parse('x * exp(x) - 2').solve('x');
      check(lambertRoots).isNotEmpty();
      final r = lambertRoots.first.evaluate();
      check(r * math.exp(r)).isCloseTo(2.0, 1e-12);
    });
  });

  group('Domain filtering and root deduplication', () {
    test('filters roots according to VariableDomain assumptions', () {
      const intAssumptions = Assumptions(defaultDomain: VariableDomain.integer);
      final imagEq = Expr.parse('x^2 + 1');
      check(imagEq.solve('x', assumptions: Assumptions.real)).isEmpty();
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
      ).isEmpty();
      check(symEq.solve('x', assumptions: Assumptions.positive))
          .deepEquals([const Variable('a')]);
      check(imagEq.solve('x', assumptions: Assumptions.positive)).isEmpty();
    });

    test(
      'isZeroExpr and deduplicateRoots handle numeric and symbolic constants',
      () {
        check(isZeroExpr(IntegerNumber.zero)).isTrue();
        check(isZeroExpr(const RealNumber(0.0))).isTrue();
        check(isZeroExpr(const RealNumber(1e-12))).isFalse();
        check(isZeroExpr(Sin(Constant.pi))).isTrue();
        check(isZeroExpr(Constant.pi)).isFalse();

        final dedup = deduplicateRoots([
          IntegerNumber.one,
          const RealNumber(1.0),
          Sin(Constant.pi),
          IntegerNumber.zero,
        ]);
        check(dedup.length).equals(2);
      },
    );
  });
}
