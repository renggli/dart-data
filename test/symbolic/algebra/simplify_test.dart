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
        Piecewise([
          (relation: LessThan(IntegerNumber.one, IntegerNumber.two), expr: x),
        ]).simplify(),
      ).equals(x);
      check(Integral(IntegerNumber.zero, 'x').simplify())
          .equals(IntegerNumber.zero);
    });
  });

  group('Indeterminate forms, domain-sound rewrites, and branch cuts', () {
    test('indeterminate infinity and undefined forms', () {
      check(Expr.parse('0 * infinity').simplify()).equals(Constant.undefined);
      check(Expr.parse('infinity - infinity').simplify())
          .equals(Constant.undefined);
      check(Expr.parse('infinity + infinity').simplify())
          .equals(Constant.infinity);
      check(Expr.parse('-infinity - infinity').simplify())
          .equals(-Constant.infinity);
      check(Expr.parse('0^(-1)').simplify()).equals(Constant.undefined);
      check(Expr.parse('ln(0)').simplify()).equals(-Constant.infinity);
      check(Expr.parse('ln(-1)').simplify())
          .equals(Mul([ComplexNumber.i, Constant.pi]));
    });

    test('domain-aware radical and power simplifications', () {
      check(Expr.parse('sqrt(x) * sqrt(y)').simplify().toString())
          .equals('sqrt(x) * sqrt(y)');
      check(
        Expr.parse('sqrt(x) * sqrt(y)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('sqrt(x * y)');

      check(Expr.parse('(x^2)^(1/2)').simplify().toString())
          .equals('sqrt(x ^ 2)');
      check(
        Expr.parse('(x^2)^(1/2)')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('abs(x)');
      check(
        Expr.parse('(x^2)^(1/2)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('x');

      check(Expr.parse('abs(x)^2').simplify().toString()).equals('abs(x) ^ 2');
      check(
        Expr.parse('abs(x)^2')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('x ^ 2');
    });

    test('logarithm power rules across domains', () {
      check(Expr.parse('ln(x^2)').simplify().toString()).equals('ln(x ^ 2)');
      check(
        Expr.parse('ln(x^2)')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('2 * ln(abs(x))');
      check(
        Expr.parse('ln(x^2)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('2 * ln(x)');
    });

    test('inverse trigonometric functions do not simplify for arbitrary x', () {
      check(Expr.parse('asin(sin(x))').simplify().toString())
          .equals('asin(sin(x))');
      check(Expr.parse('acos(cos(x))').simplify().toString())
          .equals('acos(cos(x))');
      check(Expr.parse('atan(tan(x))').simplify().toString())
          .equals('atan(tan(x))');

      check(Expr.parse('sin(asin(x))').simplify().toString()).equals('x');
      check(Expr.parse('cos(acos(x))').simplify().toString()).equals('x');
      check(Expr.parse('tan(atan(x))').simplify().toString()).equals('x');

      check(Expr.parse('asin(sin(0))').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('acos(cos(0))').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('atan(tan(0))').simplify()).equals(IntegerNumber.zero);
    });

    test('isReal fail-safe checks on negative bases and arguments', () {
      check(Pow(IntegerNumber.negativeOne, FractionNumber.half).isReal)
          .isFalse();
      check(Ln(IntegerNumber.negativeOne).isReal).isFalse();
      check(Asin(IntegerNumber.two).isReal).isFalse();
      check(Acos(IntegerNumber.two).isReal).isFalse();
      check(Atanh(IntegerNumber.two).isReal).isFalse();
      check(Acosh(IntegerNumber.zero).isReal).isFalse();
    });
  });
}
