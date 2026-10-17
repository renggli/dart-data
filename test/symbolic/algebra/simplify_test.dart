import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Algebraic simplification', () {
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

    test('trigonometric, hyperbolic, and logarithmic identities', () {
      check(Expr.parse('sin(0)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('cos(0)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('sin(-x)').simplify().toString()).equals('-sin(x)');
      check(Expr.parse('cos(-x)').simplify().toString()).equals('cos(x)');
      check(Expr.parse('sin(x)^2 + cos(x)^2').simplify())
          .equals(IntegerNumber.one);
      check(Expr.parse('5*sin(x)^2 + 5*cos(x)^2').simplify())
          .equals(IntegerNumber.of(5));
      check(Expr.parse('cosh(x)^2 - sinh(x)^2').simplify())
          .equals(IntegerNumber.one);

      check(Expr.parse('ln(1)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('ln(e)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('ln(e^3)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('exp(ln(x))').simplify()).equals(const Variable('x'));
      check(Expr.parse('ln(x) + ln(y) - ln(z)').simplify().toString())
          .equals('ln(x * y / z)');
    });

    test('power and radical simplification', () {
      check(Expr.parse('sqrt(16)').simplify()).equals(IntegerNumber.of(4));
      check(Expr.parse('sqrt(x) * sqrt(y)').simplify().toString())
          .equals('sqrt(x * y)');
      check(Expr.parse('sqrt(x^2)').simplify())
          .equals(Abs(const Variable('x')));
      check(Expr.parse('abs(-5 * x)').simplify().toString())
          .equals('abs(5 * x)');
    });
  });
}
