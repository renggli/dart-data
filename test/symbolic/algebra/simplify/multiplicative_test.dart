import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/multiplicative.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Multiplicative canonicalization and radical combination', () {
    test(
      'handles empty products, nested Mul flattening, and zero annihilator',
      () {
        const x = Variable('x');
        check(simplifyMul(const [])).equals(IntegerNumber.one);
        check(simplifyMul([Mul(const [])])).equals(IntegerNumber.one);
        check(simplifyMul([x])).equals(x);
        check(simplifyMul([x, IntegerNumber.zero])).equals(IntegerNumber.zero);
      },
    );

    test('combines radical bases with positive and negative fractional exponents', () {
      check(Expr.parse('sqrt(x) * sqrt(y)').simplify().toString())
          .equals('sqrt(x) * sqrt(y)');
      check(
        Expr.parse('sqrt(x) * sqrt(y)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('sqrt(x * y)');
      check(
        Expr.parse('sqrt(x) / sqrt(y)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('sqrt(x / y)');
      check(
        simplifyMul([
          Pow(const Variable('x'), FractionNumber.negativeHalf),
          Pow(const Variable('y'), FractionNumber.half),
        ], assumptions: Assumptions.positive).toString(),
      ).equals('sqrt(y / x)');

      // When combinedBase already exists in baseExponents (unflattened via Pow)
      const x = Variable('x');
      const y = Variable('y');
      final xy = Mul([x, y], isSimplified: true);
      final mergedExisting = simplifyMul([
        Pow(xy, IntegerNumber.two),
        Pow(x, FractionNumber.half),
        Pow(y, FractionNumber.half),
      ], assumptions: Assumptions.positive);
      check(mergedExisting.toString()).equals('(x * y) ^ (5/2)');

      final cancelledExisting = simplifyMul([
        Pow(xy, const RealNumber(-0.5)),
        Pow(x, FractionNumber.half),
        Pow(y, FractionNumber.half),
      ], assumptions: Assumptions.positive);
      check(cancelledExisting).equals(IntegerNumber.one);

      // Radical bases combination requires positive domain for denominator and at most one non-positive numerator
      check(Expr.parse('sqrt(2) / sqrt(y)').simplify().toString())
          .equals('sqrt(2) * y ^ (-1/2)');
      check(
        Expr.parse('sqrt(2) / sqrt(y)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('sqrt(2 / y)');
      check(Expr.parse('sqrt(2) * sqrt(x) * sqrt(y)').simplify().toString())
          .equals('sqrt(y) * sqrt(2 * x)');
      check(
        Expr.parse('sqrt(2) * sqrt(x) * sqrt(y)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('sqrt(2 * x * y)');
      check(Expr.parse('x^(1/3) * y^(1/3)').simplify().toString())
          .equals('x ^ (1/3) * y ^ (1/3)');
      check(
        Expr.parse('x^(1/3) * y^(1/3)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('(x * y) ^ (1/3)');
    });

    test('absorbs rational coefficients into negative integer radicals', () {
      check(Expr.parse('2 / sqrt(2)').simplify().toString()).equals('sqrt(2)');
      check(Expr.parse('6 / sqrt(3)').simplify().toString())
          .equals('2 * sqrt(3)');
      check(
        simplifyMul([
          IntegerNumber.of(4),
          Pow(IntegerNumber.two, RationalNumber(-3, 2)),
        ]).toString(),
      ).equals('sqrt(2)');

      // Product where simplifyPow produces a Mul (e.g. 12^(1/2) -> 2 * sqrt(3))
      check(
        simplifyMul([
          const Variable('x'),
          Pow(const Variable('x'), IntegerNumber.zero),
          Pow(IntegerNumber.of(12), FractionNumber.half),
        ]).toString(),
      ).equals('2 * sqrt(3) * x');

      // Product where radical bases fold to an integer Number
      check(
        simplifyMul([
          Pow(IntegerNumber.two, FractionNumber.half),
          Pow(IntegerNumber.two, FractionNumber.half),
          const Variable('x'),
        ]).toString(),
      ).equals('2 * x');
    });

    test('distributes exact division over additive factors', () {
      check(Expr.parse('(x^2 + x) / x').simplify().toString()).equals('1 + x');
      check(Expr.parse('2 * y * (x^2 + x) / x').simplify().toString())
          .equals('2 * y * (1 + x)');
      // Non-exact division is preserved as product (including Mul term with negative power)
      check(Expr.parse('(x^2 + 1) / x').simplify().toString())
          .equals('(1 + x ^ 2) / x');
      check(Expr.parse('(x^2 + y) / x').simplify().toString())
          .equals('(y + x ^ 2) / x');
    });

    test('simplifies division and sorts symbolic products with same base', () {
      check(simplifyDiv(const Variable('x'), IntegerNumber.zero))
          .equals(Constant.undefined);
      check(simplifyDiv(IntegerNumber.of(6), IntegerNumber.two))
          .equals(IntegerNumber.of(3));

      const x = Variable('x');
      final sorted = simplifySymbolicProduct(IntegerNumber.one, [
        Pow(x, IntegerNumber.of(3)),
        Pow(x, IntegerNumber.two),
      ]);
      check(sorted.toString()).equals('x ^ 2 * x ^ 3');
    });
  });

  group('OrderTerm multiplication rules', () {
    test(
      'absorbs scalars, constants, powers, and merges matching OrderTerms',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');
        const ord2 = OrderTerm('x', 2);
        const ord3 = OrderTerm('x', 3);

        check(simplifyMul([ord2, ord3])).equals(const OrderTerm('x', 5));
        check(simplifyMul([IntegerNumber.of(5), ord2])).equals(ord2);
        check(simplifyMul([Constant.pi, ord2])).equals(ord2);
        check(simplifyMul([x, ord2])).equals(ord3);
        check(simplifyMul([Pow(x, IntegerNumber.of(3)), ord2]))
            .equals(const OrderTerm('x', 5));

        // Shifted point OrderTerm multiplication
        const shiftedOrd = OrderTerm('x', 2, point: IntegerNumber.one);
        final shiftedVar = x - IntegerNumber.one;
        check(simplifyMul([shiftedVar, shiftedOrd]))
            .equals(const OrderTerm('x', 3, point: IntegerNumber.one));
        check(simplifyMul([Pow(shiftedVar, IntegerNumber.of(3)), shiftedOrd]))
            .equals(const OrderTerm('x', 5, point: IntegerNumber.one));

        // Distributing OrderTerm over Add (collapsing and non-collapsing)
        check(
          simplifyMul([
            Add([IntegerNumber.one, x]),
            ord2,
          ]),
        ).equals(ord2);
        check(
          simplifyMul([
            ord2,
            Add([y, z]),
          ]).toString(),
        ).equals('y * O(x^2) + z * O(x^2)');
        check(
          simplifyMul([
            y,
            ord2,
            Add([y, z]),
          ]).toString(),
        ).equals('y * (y * O(x^2) + z * O(x^2))');
      },
    );
  });
}
