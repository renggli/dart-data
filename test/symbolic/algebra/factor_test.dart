import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Univariate and multivariate polynomial factorization', () {
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

      // Pure negative power and product of negative powers
      final negPow = Expr.parse('(x^2 - 1)^(-2)').factor();
      check(negPow.evaluate({'x': 2.0})).isCloseTo(1.0 / 9.0, 1e-12);

      final posPow = Expr.parse('(x^2 - 1)^2').factor();
      check(posPow.evaluate({'x': 2.0})).equals(9.0);

      final invProd = Mul([
        Pow(Expr.parse('x - 1'), IntegerNumber.negativeOne),
        Pow(Expr.parse('x + 1'), IntegerNumber.negativeOne),
      ]).factor();
      check(invProd.evaluate({'x': 2.0})).isCloseTo(1.0 / 3.0, 1e-12);
    });

    test('handles expressions that collapse to atomic or power nodes upon expansion', () {
      check(IntegerNumber.of(5).factor()).equals(IntegerNumber.of(5));
      check(Constant.pi.factor()).equals(Constant.pi);
      check(const Variable('x').factor()).equals(const Variable('x'));

      // (x + 1) - x -> 1 (atomic after expand)
      check(Expr.parse('(x + 1) - x').factor()).equals(IntegerNumber.one);

      // (x + 1)^2 - 2*x - 1 -> x^2 (Pow after expand)
      check(Expr.parse('(x + 1)^2 - 2*x - 1').factor())
          .equals(Pow(const Variable('x'), IntegerNumber.two));

      // 4-term grouping via factor()
      final grouped = Expr.parse('x * y + x + y + 1').factor();
      check(grouped).equals(Expr.parse('(1 + x) * (1 + y)').simplify());
    });

    test(
      'factors composite integers and rational numbers into prime powers',
      () {
        check(IntegerNumber.zero.factor()).equals(IntegerNumber.zero);
        check(IntegerNumber.one.factor()).equals(IntegerNumber.one);
        check(IntegerNumber.negativeOne.factor())
            .equals(IntegerNumber.negativeOne);
        check(IntegerNumber.of(7).factor()).equals(IntegerNumber.of(7));

        final f360 = IntegerNumber.of(360).factor();
        check(f360.toString()).equals('2 ^ 3 * 3 ^ 2 * 5');
        check(f360.simplify()).equals(IntegerNumber.of(360));

        final fNeg12 = IntegerNumber.of(-12).factor();
        check(fNeg12.toString()).equals('-(2 ^ 2 * 3)');
        check(fNeg12.simplify()).equals(IntegerNumber.of(-12));

        final fRat = RationalNumber(12, 25).factor();
        check(fRat.toString()).equals('2 ^ 2 * 3 / 5 ^ 2');
        check(fRat.simplify()).equals(RationalNumber(12, 25));
      },
    );
  });

  group('Special algebraic forms and canonical ordering', () {
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

    test('factors multivariate sum and difference of cubes', () {
      final diffCubes = Expr.parse('x^3 - y^3').factor();
      check(diffCubes).isA<Mul>();
      check((diffCubes.expand() - Expr.parse('x^3 - y^3')).simplify())
          .equals(IntegerNumber.zero);
      check(diffCubes)
          .equals(Expr.parse('(x - y) * (x^2 + x*y + y^2)').simplify());

      final sumCubes = Expr.parse('8*x^3 + 27*y^3').factor();
      check(sumCubes).isA<Mul>();
      check((sumCubes.expand() - Expr.parse('8*x^3 + 27*y^3')).simplify())
          .equals(IntegerNumber.zero);
      check(
        sumCubes,
      ).equals(Expr.parse('(2*x + 3*y) * (4*x^2 - 6*x*y + 9*y^2)').simplify());
    });

    test(
      'performs square-free decomposition on repeated irreducible factors',
      () {
        final sqFree1 = Expr.parse('x^4 + 2*x^2 + 1').factor();
        check(sqFree1).equals(Expr.parse('(1 + x^2)^2').simplify());

        final sqFree2 = Expr.parse('x^4 + 2*x^3 + 3*x^2 + 2*x + 1').factor();
        check(sqFree2).equals(Expr.parse('(1 + x + x^2)^2').simplify());
      },
    );
  });
}
