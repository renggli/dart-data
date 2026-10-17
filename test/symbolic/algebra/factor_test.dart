import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Polynomial factorization', () {
    test('factors univariate polynomials over Q[x]', () {
      final f1 = Expr.parse('x^2 - 4').factor();
      check((f1.expand() - Expr.parse('x^2 - 4')).simplify())
          .equals(IntegerNumber.zero);

      final f2 = Expr.parse('x^3 - 6*x^2 + 11*x - 6').factor();
      check(f2).isA<Mul>();
      check((f2.expand() - Expr.parse('x^3 - 6*x^2 + 11*x - 6')).simplify())
          .equals(IntegerNumber.zero);

      final biquad = Expr.parse('x^4 - 5*x^2 + 4').factor();
      check((biquad.expand() - Expr.parse('x^4 - 5*x^2 + 4')).simplify())
          .equals(IntegerNumber.zero);
    });

    test('factors multivariate polynomials and cancels rational fractions', () {
      final f3 = Expr.parse('x^2 - y^2').factor();
      check(f3).isA<Mul>();
      check((f3.expand() - Expr.parse('x^2 - y^2')).simplify())
          .equals(IntegerNumber.zero);

      final rat = Expr.parse('(x^2 - 1) / (x - 1)').factor();
      check(rat).equals(Expr.parse('x + 1').simplify());
    });

    test('orders terms and factors identically to simplify()', () {
      for (final input in [
        'x^3 - 3*x + 1',
        '8*x^4 - 8*x^2 + 1',
        'x^2 + 2*x + 5',
        '(x - 1) * (x - 2) * (x + 2)',
        '(x - 1) * (x + 1) * (x^2 + 1)',
        'x * exp(x) - 2',
        'sin(x)^2 + cos(x)^2',
      ]) {
        final expr = Expr.parse(input);
        check(expr.factor()).equals(expr.simplify());
      }

      check(Expr.parse('x^2 - 5*x + 6').factor())
          .equals(Expr.parse('(x - 2) * (x - 3)').simplify());
      check(Expr.parse('2*x*y + 4*x').factor())
          .equals(Expr.parse('2 * x * (2 + y)').simplify());
    });
  });
}
