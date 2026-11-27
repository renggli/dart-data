import 'package:checks/checks.dart';
import 'package:data/src/symbolic/calculus/product.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const k = Variable('k');
  const n = Variable('n');

  group('computeProduct', () {
    test('factorial product', () {
      final res = computeProduct(
        k,
        'k',
        IntegerNumber.one,
        n,
        assumptions: Assumptions.none,
      );
      check(res).equals(Fn.factorial(n));
    });

    test('telescoping product', () {
      final res = computeProduct(
        (k + IntegerNumber.one) / k,
        'k',
        IntegerNumber.one,
        n,
        assumptions: Assumptions.none,
      );
      check(res.toString()).equals('1 + n');
    });

    test('infinite Wallis product', () {
      final expr =
          (IntegerNumber.of(4) * k * k) /
          (IntegerNumber.of(4) * k * k - IntegerNumber.one);
      final res = computeProduct(
        expr,
        'k',
        IntegerNumber.one,
        Constant.infinity,
        assumptions: Assumptions.none,
      );
      check(res.toString()).equals('1/2 * pi');
    });

    test('concrete integer product', () {
      final res = computeProduct(
        k,
        'k',
        IntegerNumber.one,
        IntegerNumber.of(5),
        assumptions: Assumptions.none,
      );
      check(res).equals(IntegerNumber.of(120));
    });

    test('uses DomainOracle assumptions in Euler infinite products', () {
      const a = Variable('a');
      final negAssump = Assumptions.none.withNegative('a');
      final prod = computeProduct(
        IntegerNumber.one - a / (k * k),
        'k',
        IntegerNumber.one,
        Constant.infinity,
        assumptions: negAssump,
      );
      final sqrtNegA = Pow.of(-a, FractionNumber.half);
      final expected =
          (Fn.sinh(Constant.pi * sqrtNegA) / (Constant.pi * sqrtNegA)).simplify(
            assumptions: negAssump,
          );
      check(prod).equals(expected);
    });
  });
}
