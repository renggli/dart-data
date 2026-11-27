import 'package:checks/checks.dart';
import 'package:data/src/symbolic/oracle/domain_oracle.dart';
import 'package:data/src/symbolic/oracle/interval.dart';
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
  });
}
