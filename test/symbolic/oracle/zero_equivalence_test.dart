import 'package:checks/checks.dart';
import 'package:data/src/symbolic/oracle/zero_equivalence.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Zero-equivalence oracle (testZero and isZeroExpr)', () {
    const x = Variable('x');

    test('decides exact zero and guaranteed non-zero expressions', () {
      check(testZero(IntegerNumber.zero)).equals(Truth.yes);
      check(testZero(IntegerNumber.of(7))).equals(Truth.no);
      check(testZero(Constant.undefined)).equals(Truth.unknown);
      check(testZero(x, assumptions: Assumptions.positive)).equals(Truth.no);
      check(testZero(x * x + IntegerNumber.one, assumptions: Assumptions.real))
          .equals(Truth.no);
    });

    test('verifies algebraic equivalence and optional numeric disproof', () {
      final a = Expr.parse('(x + 1)^2 - (x^2 + 2*x + 1)');
      final b = Expr.parse('1 / (x - 1) + 1 / (x + 1) - 2 * x / (x^2 - 1)');
      check(isZeroExpr(a)).isTrue;
      check(isZeroExpr(b)).isTrue;
      check(areEquivalent(Expr.parse('(x + 1)^2'), Expr.parse('x^2 + 2*x + 1')))
          .isTrue;

      final nonZeroTrig = Expr.parse('sin(x)^2 + cos(x)');
      check(testZero(nonZeroTrig)).equals(Truth.unknown);
      check(testZero(nonZeroTrig, numericDisproof: true)).equals(Truth.no);
    });
  });
}
