import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Canonical algebraic simplification', () {
    test(
      'additive and multiplicative canonicalization in increasing order',
      () {
        check(Expr.parse('x + 0').simplify()).equals(const Variable('x'));
        check(Expr.parse('x - x').simplify()).equals(IntegerNumber.zero);
        check(Expr.parse('2*x + 3*x').simplify().toString()).equals('5 * x');
        check(Expr.parse('x * 1').simplify()).equals(const Variable('x'));
        check(Expr.parse('x * 0').simplify()).equals(IntegerNumber.zero);
        check(Expr.parse('x * x^2').simplify().toString()).equals('x ^ 3');
        check(Expr.parse('x^3 / x').simplify().toString()).equals('x ^ 2');

        // Increasing degree order
        check(Expr.parse('x^3 + 2*x + 1 + x^2').simplify().toString())
            .equals('1 + 2 * x + x ^ 2 + x ^ 3');
      },
    );

    test('exact Gaussian complex arithmetic and powers of i', () {
      check(Expr.parse('i^2').simplify()).equals(IntegerNumber.negativeOne);
      check(Expr.parse('i^3').simplify()).equals(-ComplexNumber.i);
      check(Expr.parse('i^4').simplify()).equals(IntegerNumber.one);

      final prod = Expr.parse('(1 + 2*i) * (3 - 4*i)').simplify();
      check(prod).isA<ComplexNumber>();
      check(prod.toString()).equals('11 + 2 * i');

      final quot = Expr.parse('(11 + 2*i) / (3 - 4*i)').simplify();
      check(quot).isA<ComplexNumber>();
      check(quot.toString()).equals('1 + 2 * i');
    });
  });

  group('Dispatch across all AST node types in simplifyExpr', () {
    test('dispatches OrderTerm, special functions, relational, piecewise, and integral', () {
      const x = Variable('x');
      check(
        OrderTerm(
          'x',
          2,
          point: IntegerNumber.one + IntegerNumber.zero,
        ).simplify(),
      ).equals(const OrderTerm('x', 2, point: IntegerNumber.one));

      check(Sinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Cosh(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Tanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Asinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Acosh(IntegerNumber.one).simplify()).equals(IntegerNumber.zero);
      check(Atanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(LambertW(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Erf(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Erfc(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Gamma(IntegerNumber.of(4)).simplify()).equals(IntegerNumber.of(6));
      check(Beta(IntegerNumber.two, IntegerNumber.of(3)).simplify())
          .equals(RationalNumber(1, 12));

      check(LessThan(IntegerNumber.one, IntegerNumber.two).simplify())
          .equals(IntegerNumber.one);
      check(
        Piecewise([(LessThan(IntegerNumber.one, IntegerNumber.two), x)])
            .simplify(),
      ).equals(x);
      check(Integral(IntegerNumber.zero, 'x').simplify())
          .equals(IntegerNumber.zero);
    });
  });
}
