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

    test(
      'evaluates constant, degenerate, negative, and upper-shifted products',
      () {
        check(
          computeProduct(
            IntegerNumber.one,
            'k',
            IntegerNumber.one,
            IntegerNumber.of(5),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.one);
        check(
          computeProduct(
            k,
            'k',
            IntegerNumber.of(5),
            IntegerNumber.one,
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.one);
        check(
          computeProduct(
            IntegerNumber.two * k,
            'k',
            IntegerNumber.of(-2),
            IntegerNumber.two,
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.zero);
        check(
          computeProduct(
            IntegerNumber.two * k,
            'k',
            IntegerNumber.of(-4),
            IntegerNumber.negativeOne,
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.of(384));
        check(
          computeProduct(
            IntegerNumber.two * k,
            'k',
            IntegerNumber.of(3),
            const Variable('n'),
            assumptions: Assumptions.none,
          ).substitute('n', IntegerNumber.of(5)).simplify(),
        ).equals(IntegerNumber.of(480));
        check(
          computeProduct(
            k + IntegerNumber.of(3),
            'k',
            IntegerNumber.zero,
            const Variable('n'),
            assumptions: Assumptions.none,
          ).substitute('n', IntegerNumber.of(4)).simplify(),
        ).equals(IntegerNumber.of(2520));
      },
    );
  });
}
