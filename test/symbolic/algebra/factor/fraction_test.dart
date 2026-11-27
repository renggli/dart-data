import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/factor/fraction.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Monomial detection and factored expression building', () {
    test('isMonomial recognizes variables, powers, and products', () {
      const x = Variable('x');
      const y = Variable('y');

      check(isMonomial(x)).isTrue;
      check(isMonomial(Pow.of(x, IntegerNumber.two))).isTrue;
      check(isMonomial(Mul.of([x, Pow.of(y, IntegerNumber.of(3))]))).isTrue;
      check(isMonomial(Add.of([x, y]))).isFalse;
      check(isMonomial(IntegerNumber.two)).isFalse;
    });

    test(
      'buildFactoredExpr handles positive, zero, and unit multiplicities',
      () {
        const x = Variable('x');
        const y = Variable('y');
        final expr = buildFactoredExpr(
          scalar: IntegerNumber.of(3),
          factors: {x: 1, y: 2, const Variable('z'): 0},
        );
        check(expr.toString()).equals('3 * x * y ^ 2');
      },
    );
  });

  group('Rational fraction cancellation and power distribution', () {
    test('cancelFactoredFraction cancels common factors with higher/lower multiplicities', () {
      const x = Variable('x');
      const y = Variable('y');

      // Numerator multiplicity > denominator multiplicity, and vice versa
      final num = Mul.of([
        IntegerNumber.of(6),
        Pow.of(x, IntegerNumber.of(3)),
        y,
      ]);
      final den = Mul.of([
        IntegerNumber.two,
        x,
        Pow.of(y, IntegerNumber.of(4)),
      ]);
      final cancelled = cancelFactoredFraction(num, den);
      check(cancelled.toString()).equals('3 * x ^ 2 / y ^ 3');

      check(cancelFactoredFraction(x, IntegerNumber.zero))
          .equals(Constant.undefined);
    });

    test(
      'distributePower distributes across products, negative ones, and powers',
      () {
        const x = Variable('x');
        const y = Variable('y');

        check(distributePower(x, 1)).equals(x);
        check(distributePower(RationalNumber(2, 3), 2))
            .equals(RationalNumber(4, 9));
        check(distributePower(Pow.of(x, FractionNumber.half), 4))
            .equals(Pow.of(x, IntegerNumber.two));

        // Mul with -1 raised to even and odd exponents
        check(distributePower(Mul.of([IntegerNumber.negativeOne]), 2))
            .equals(IntegerNumber.one);
        check(distributePower(Mul.of([IntegerNumber.negativeOne]), 3))
            .equals(IntegerNumber.negativeOne);
        check(
          distributePower(
            Mul.of([IntegerNumber.negativeOne, x, y]),
            2,
          ).toString(),
        ).equals('x ^ 2 * y ^ 2');
        check(
          distributePower(
            Mul.of([IntegerNumber.negativeOne, x, y]),
            3,
          ).toString(),
        ).equals('-x ^ 3 * y ^ 3');
      },
    );

    test('flattenFactored handles negative powers and non-power factors', () {
      const x = Variable('x');
      final combined = combineFactoredProducts([
        IntegerNumber.two,
        Pow.of(x, IntegerNumber.negativeOne),
        Fn.sin(x),
      ]);
      check(combined.toString()).equals('2 * sin(x) / x');
    });
  });
}
