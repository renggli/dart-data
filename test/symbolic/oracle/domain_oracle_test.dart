import 'package:checks/checks.dart';
import 'package:data/src/symbolic/oracle/domain_oracle.dart';
import 'package:data/src/symbolic/oracle/interval.dart';
import 'package:data/src/symbolic/oracle/sign.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('DomainOracle interval and realness proofs', () {
    test(
      'proves range-restricted functions real using interval enclosures',
      () {
        const realX = Assumptions(domains: {'x': VariableDomain.real});
        final oracle = DomainOracle(realX);

        check(oracle.isReal(Expr.parse('asin(sin(x))'))).isTrue;
        check(oracle.isReal(Expr.parse('acos(cos(x))'))).isTrue;
        final x2p1 = Expr.parse('x^2 + 1');
        check(oracle.isPositive(x2p1)).isTrue;
        check(oracle.isReal(Fn.ln(x2p1))).isTrue;
        check(oracle.isReal(Fn.acosh(x2p1))).isTrue;
        check(oracle.isPositive(Pow.of(x2p1, FractionNumber.half))).isTrue;
        check(oracle.isPositive(Expr.parse('ln(x^2 + 2)'))).isTrue;
      },
    );

    test('uses VariableBounds to classify signs and intervals', () {
      final bounded = Assumptions.none.withBounds(
        'x',
        lower: IntegerNumber.two,
        lowerInclusive: true,
        upper: IntegerNumber.of(5),
      );
      final oracle = DomainOracle(bounded);

      final iv = oracle.intervalOf(Expr.parse('x - 2'));
      check(iv.isNonNegative).isTrue;
      check(oracle.isNonNegative(Expr.parse('x - 2'))).isTrue;
      check(oracle.isPositive(Expr.parse('x - 1'))).isTrue;
      check(oracle.isNegative(Expr.parse('x - 6'))).isTrue;
      check(oracle.isNonPositive(Expr.parse('x - 5'))).isTrue;

      check(Expr.parse('abs(x - 2)').simplify(assumptions: bounded))
          .equals(Expr.parse('x - 2').simplify());
      check(Expr.parse('abs(x - 5)').simplify(assumptions: bounded))
          .equals(Expr.parse('5 - x').simplify());
    });

    test('evaluates closed-constant signs and caches DAG queries', () {
      final oracle = DomainOracle(Assumptions.none);
      check(oracle.signOf(Expr.parse('pi - 3'))).equals(Sign.positive);
      check(oracle.signOf(Expr.parse('e - 3'))).equals(Sign.negative);
      check(oracle.signOf(Expr.parse('e - 3'))).equals(Sign.negative);
      check(oracle.intervalOf(ComplexNumber.i)).equals(RealInterval.empty);

      final intOracle = DomainOracle(
        const Assumptions(domains: {'n': VariableDomain.integer}),
      );
      check(intOracle.isInteger(Expr.parse('2 * n + 1'))).isTrue;
      check(intOracle.isEvenInteger(Expr.parse('2 * n'))).isTrue;
      check(intOracle.isOddInteger(Expr.parse('2 * n + 1'))).isTrue;
    });

    test('evaluates top-level sign and realness predicate wrappers', () {
      const x = Variable('x');
      const realAssumptions = Assumptions(domains: {'x': VariableDomain.real});
      const posAssumptions = Assumptions(
        domains: {'x': VariableDomain.positive},
      );
      const intAssumptions = Assumptions(
        domains: {'x': VariableDomain.integer},
      );

      check(isProvenReal(IntegerNumber.of(5), Assumptions.none)).isTrue;
      check(isProvenReal(FractionNumber.half, Assumptions.none)).isTrue;
      check(isProvenReal(const RealNumber(3.14), Assumptions.none)).isTrue;
      check(isProvenReal(Constant.pi, Assumptions.none)).isTrue;
      check(isProvenReal(ComplexNumber.i, Assumptions.none)).isFalse;
      check(isProvenReal(x, Assumptions.none)).isFalse;
      check(isProvenReal(x, realAssumptions)).isTrue;
      check(isProvenReal(x, posAssumptions)).isTrue;
      check(isProvenReal(x, intAssumptions)).isTrue;
      check(
        isProvenReal(
          x,
          const Assumptions(domains: {'x': VariableDomain.complex}),
        ),
      ).isFalse;
      check(isProvenReal(Fn.sin(x), realAssumptions)).isTrue;
      check(isProvenReal(Fn.abs(x), Assumptions.none)).isTrue;
      check(isProvenReal(Fn.re(x), Assumptions.none)).isTrue;
      check(isProvenReal(Fn.im(x), Assumptions.none)).isTrue;
      check(isProvenReal(Fn.arg(x), Assumptions.none)).isTrue;
      check(isProvenReal(Fn.ellipticK(x), Assumptions.real)).isFalse;
      check(isProvenReal(Fn.ellipticK(FractionNumber.half), Assumptions.real))
          .isTrue;
      check(isProvenReal(Fn.ellipticK(IntegerNumber.one), Assumptions.none))
          .isFalse;
      check(isProvenReal(Fn.ellipticE(IntegerNumber.one), Assumptions.none))
          .isTrue;
      check(
        isProvenReal(
          Fn.besselK(IntegerNumber.zero, IntegerNumber.negativeOne),
          Assumptions.none,
        ),
      ).isFalse;
      check(
        isProvenReal(
          Fn.besselY(IntegerNumber.zero, IntegerNumber.negativeOne),
          Assumptions.none,
        ),
      ).isFalse;
      check(
        isProvenReal(
          Fn.upperGamma(IntegerNumber.one, IntegerNumber.negativeOne),
          Assumptions.none,
        ),
      ).isFalse;
      check(isProvenReal(Fn.gamma(IntegerNumber.zero), Assumptions.none))
          .isFalse;

      check(isPositiveExpr(IntegerNumber.of(3), assumptions: Assumptions.none))
          .isTrue;
      check(isPositiveExpr(IntegerNumber.zero, assumptions: Assumptions.none))
          .isFalse;
      check(isPositiveExpr(x, assumptions: posAssumptions)).isTrue;
      check(isPositiveExpr(Fn.cosh(x), assumptions: Assumptions.real)).isTrue;
      check(
        isPositiveExpr(
          Expr.parse('(-2) * (-x)'),
          assumptions: Assumptions.positive,
        ),
      ).isTrue;
      check(
        isNegativeExpr(Expr.parse('-2 * x'), assumptions: Assumptions.positive),
      ).isTrue;
      check(isNonNegativeExpr(Fn.abs(x), assumptions: Assumptions.none)).isTrue;
      check(
        isNonNegativeExpr(
          Pow.of(IntegerNumber.two, ComplexNumber.i),
          assumptions: Assumptions.none,
        ),
      ).isFalse;
      check(
        isNonNegativeExpr(
          Pow.of(IntegerNumber.zero, IntegerNumber.negativeOne),
          assumptions: Assumptions.none,
        ),
      ).isFalse;
      check(
        isNonNegativeExpr(
          Fn.abs(Constant.undefined),
          assumptions: Assumptions.none,
        ),
      ).isFalse;

      check(isIntegerExpr(IntegerNumber.of(42), assumptions: Assumptions.none))
          .isTrue;
      check(isIntegerExpr(FractionNumber.half, assumptions: Assumptions.none))
          .isFalse;
      check(isIntegerExpr(x, assumptions: intAssumptions)).isTrue;
      check(
        isIntegerExpr(
          Fn.floor(Constant.undefined),
          assumptions: Assumptions.none,
        ),
      ).isFalse;
      check(isIntegerExpr(Fn.floor(x), assumptions: Assumptions.real)).isTrue;
      check(
        isEvenIntegerExpr(IntegerNumber.of(4), assumptions: Assumptions.none),
      ).isTrue;
      check(
        isEvenIntegerExpr(
          Mul.of([IntegerNumber.two, x]),
          assumptions: intAssumptions,
        ),
      ).isTrue;

      check(tryStaticRealValue(IntegerNumber.of(7))).equals(7.0);
      check(tryStaticRealValue(const RealNumber(2.5))).equals(2.5);
      check(tryStaticRealValue(Constant.pi)).isNotNull();
      check(tryStaticRealValue(ComplexNumber.i)).isNull;
      check(tryStaticRealValue(x)).isNull;
    });
  });
}
