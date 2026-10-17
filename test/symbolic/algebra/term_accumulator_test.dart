import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/term_accumulator.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('MonomialAccumulator and term decomposition', () {
    test('accumulates like monomials and extracts polynomial coefficients', () {
      final acc = MonomialAccumulator();
      acc.add(Expr.parse('3 * x^2 + 2 * x - 5'));
      acc.add(Expr.parse('x^2 - 2 * x + 1'));

      final coeffs = acc.extractPolynomialCoefficients('x');
      check(coeffs).isNotNull();
      check(coeffs![0]).equals(IntegerNumber.of(-4));
      check(coeffs.containsKey(1)).isFalse();
      check(coeffs[2]).equals(IntegerNumber.of(4));

      check(acc.build().toString()).equals('-4 + 4 * x ^ 2');
    });

    test('splitNumeratorDenominator extracts fraction and negative power denominators', () {
      final (num1, den1) = splitNumeratorDenominator(
        Expr.parse('3 / 4 * x / (y + 1)').simplify(),
      );
      check(num1.toString()).equals('3 * x');
      check(den1.toString()).equals('4 * (1 + y)');
    });
  });
}
