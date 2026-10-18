import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/power.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Trivial and exponential base power identities', () {
    test('simplifies zero/unit exponents and zero/unit bases', () {
      const x = Variable('x');
      check(simplifyPow(x, IntegerNumber.zero)).equals(IntegerNumber.one);
      check(simplifyPow(x, IntegerNumber.one)).equals(x);
      check(simplifyPow(IntegerNumber.one, x)).equals(IntegerNumber.one);
      check(simplifyPow(IntegerNumber.zero, IntegerNumber.two))
          .equals(IntegerNumber.zero);

      check(() => simplifyPow(IntegerNumber.zero, IntegerNumber.negativeOne))
          .throws<UnsupportedError>();
      check(
        () => simplifyPow(IntegerNumber.zero, Mul([IntegerNumber.of(-2), x])),
      ).throws<UnsupportedError>();
    });

    test('simplifies natural exponential powers of logarithms', () {
      const x = Variable('x');
      const y = Variable('y');
      check(simplifyPow(Constant.e, Ln(x))).equals(x);
      check(simplifyPow(Constant.e, Mul([IntegerNumber.of(3), Ln(x)])))
          .equals(Pow(x, IntegerNumber.of(3), isSimplified: true));
      check(
        simplifyPow(Constant.e, Mul([IntegerNumber.two, y, Ln(x)])).toString(),
      ).equals('x ^ (2 * y)');
    });
  });

  group('Numeric and radical power simplification', () {
    test(
      'evaluates rational, complex, and negative-base fractional powers',
      () {
        check(simplifyPow(IntegerNumber.of(-4), FractionNumber.half).toString())
            .equals('2 * i');
        check(
          simplifyPow(
            IntegerNumber.of(-4),
            FractionNumber.negativeHalf,
          ).toString(),
        ).equals('-1/2 * i');
        check(
          simplifyPow(IntegerNumber.of(-2), FractionNumber.third).toString(),
        ).equals('(-2) ^ (1/3)');

        check(simplifyPow(ComplexNumber.i, IntegerNumber.two))
            .equals(IntegerNumber.negativeOne);
        check(simplifyPow(ComplexNumber.i, FractionNumber.half).toString())
            .equals('sqrt(i)');
        check(
          simplifyPow(const RealNumber(2.5), const RealNumber(3.5)).toString(),
        ).equals('2.5 ^ 3.5');

        check(foldRationalPower(const Integer(2), const Integer(3), 2))
            .equals(RationalNumber(4, 9));
        check(foldRationalPower(const Integer(2), const Integer(3), 2000))
            .isA<Pow>();
      },
    );

    test('extracts integer and rational q-th power radicals', () {
      check(Expr.parse('sqrt(12)').simplify().toString()).equals('2 * sqrt(3)');
      check(Expr.parse('sqrt(72 / 25)').simplify().toString())
          .equals('6/5 * sqrt(2)');
      check(Expr.parse('2^(5/2)').simplify().toString()).equals('4 * sqrt(2)');
      check(Expr.parse('(54 / 125)^(1/3)').simplify().toString())
          .equals('3/5 * 2 ^ (1/3)');
      check(Expr.parse('(16 / 81)^(1/3)').simplify().toString())
          .equals('2/3 * (2/3) ^ (1/3)');

      // Large denominator > 64 stays unextracted
      final largeRoot = simplifyPow(
        IntegerNumber.of(4),
        RationalNumber(1, 100),
      );
      check(largeRoot).isA<Pow>();
    });
  });

  group('Composite base power rules', () {
    test('simplifies nested powers, products, abs squares, and OrderTerms', () {
      const x = Variable('x');
      const y = Variable('y');

      // (u^2)^(1/2) -> |u| (including with RealNumber 2.0 and 0.5)
      check(simplifyPow(Pow(x, const RealNumber(2.0)), const RealNumber(0.5)))
          .equals(Abs(x));

      // Nested powers: (e^x)^y -> e^(x*y), (x^(1/3))^(3/2) -> x^(1/2), (x^y)^2 -> x^(2*y)
      check(simplifyPow(Pow(Constant.e, x), y).toString()).equals('exp(x * y)');
      check(
        simplifyPow(
          Pow(x, FractionNumber.third),
          RationalNumber(3, 2),
        ).toString(),
      ).equals('sqrt(x)');
      check(simplifyPow(Pow(x, y), IntegerNumber.two).toString())
          .equals('x ^ (2 * y)');

      // Product raised to integer power: (2 * x)^3 -> 8 * x^3
      check(
        simplifyPow(
          Mul([IntegerNumber.two, x]),
          IntegerNumber.of(3),
        ).toString(),
      ).equals('8 * x ^ 3');

      // Product raised to fractional power: sqrt(4 * pi^2) -> 2 * pi
      check(Expr.parse('sqrt(4 * pi^2)').simplify().toString())
          .equals('2 * pi');
      check(Expr.parse('sqrt(12 * x^2)').simplify().toString())
          .equals('2 * sqrt(3) * abs(x)');
      check(Expr.parse('sqrt(4 * exp(2 * x))').simplify().toString())
          .equals('2 * exp(x)');

      // Tangent of f(x) = sqrt(x^2) + abs(x) at x0 = -2 * pi simplifies to -2 * x
      final f = Expr.parse('sqrt(x^2) + abs(x)');
      final x0 = Expr.parse('-2 * pi').simplify();
      final fx0 = f.substitute('x', x0).simplify();
      final dfx0 = f.derivative('x').simplify().substitute('x', x0).simplify();
      final tangent = (fx0 + dfx0 * (x - x0)).expand().simplify();
      check(tangent.toString()).equals('-2 * x');

      // |x|^2 -> x^2
      check(simplifyPow(Abs(x), IntegerNumber.two).toString()).equals('x ^ 2');

      // OrderTerm^k -> OrderTerm(var, order * k)
      check(simplifyPow(const OrderTerm('x', 2), IntegerNumber.of(3)))
          .equals(const OrderTerm('x', 6));
    });
  });
}
