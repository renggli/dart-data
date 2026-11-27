import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

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
      ).equals(OrderTerm('x', 2, point: IntegerNumber.one));

      check(Fn.sinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.cosh(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Fn.tanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.asinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.acosh(IntegerNumber.one).simplify()).equals(IntegerNumber.zero);
      check(Fn.atanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.lambertW(IntegerNumber.zero).simplify())
          .equals(IntegerNumber.zero);
      check(Fn.erf(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.erfc(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Fn.gamma(IntegerNumber.of(4)).simplify())
          .equals(IntegerNumber.of(6));
      check(Fn.beta(IntegerNumber.two, IntegerNumber.of(3)).simplify())
          .equals(RationalNumber(1, 12));

      check(
        Relational.lessThan(IntegerNumber.one, IntegerNumber.two).simplify(),
      ).equals(IntegerNumber.one);
      check(
        Piecewise([
          (
            relation: Relational.lessThan(IntegerNumber.one, IntegerNumber.two),
            expr: x,
          ),
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
          .equals(Mul.of([ComplexNumber.i, Constant.pi]));
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

      check(Expr.parse('abs(x^2)').simplify().toString()).equals('abs(x) ^ 2');
      check(
        Expr.parse('abs(x^2)')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('x ^ 2');

      check(Expr.parse('sqrt(exp(x))').simplify().toString())
          .equals('sqrt(exp(x))');
      check(
        Expr.parse('sqrt(exp(x))')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('exp(1/2 * x)');

      check(Expr.parse('re(x)').simplify().toString()).equals('re(x)');
      check(Expr.parse('re(x)').simplify(assumptions: Assumptions.real))
          .equals(const Variable('x'));
      check(Expr.parse('im(x)').simplify().toString()).equals('im(x)');
      check(Expr.parse('im(x)').simplify(assumptions: Assumptions.real))
          .equals(IntegerNumber.zero);
      check(Expr.parse('conj(x)').simplify().toString()).equals('conj(x)');
      check(Expr.parse('conj(x)').simplify(assumptions: Assumptions.real))
          .equals(const Variable('x'));
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
      check(Pow.of(IntegerNumber.negativeOne, FractionNumber.half).isReal)
          .isFalse;
      check(Fn.ln(IntegerNumber.negativeOne).isReal).isFalse;
      check(Fn.asin(IntegerNumber.two).isReal).isFalse;
      check(Fn.acos(IntegerNumber.two).isReal).isFalse;
      check(Fn.atanh(IntegerNumber.two).isReal).isFalse;
      check(Fn.acosh(IntegerNumber.zero).isReal).isFalse;
    });

    test('conjugate distributes over entire special functions', () {
      const z = Variable('z');
      for (final fn in [
        Fn.erfi(z),
        Fn.fresnelS(z),
        Fn.fresnelC(z),
        Fn.si(z),
        Fn.shi(z),
      ]) {
        final conj = Fn.conj(fn).simplify();
        check(conj.toString()).not(.it()..startsWith('conj('));
      }
      check(Fn.conj(Fn.erfi(ComplexNumber.i)).simplify())
          .equals(Fn.erfi(-ComplexNumber.i).simplify());
    });

    test('memoization preserves DAG equivalence and unchanged leaves', () {
      const x = Variable('x');
      final e = Expr.parse('(sin(x) + 1)^2 * (sin(x) + 1)^3');
      check(e.simplify(assumptions: Assumptions.real))
          .equals(Expr.parse('(1 + sin(x))^5').simplify());

      final fn = Call.symbolic('f', const [x]);
      check(identical(fn.simplify(assumptions: Assumptions.real), fn)).isTrue;
      final ord = OrderTerm('x', 2);
      check(identical(ord.simplify(assumptions: Assumptions.real), ord)).isTrue;
    });

    test('simplifies exp of inverse hyperbolic functions', () {
      check(Expr.parse('exp(atanh(x))').simplify())
          .equals(Expr.parse('((1 + x) / (1 - x))^(1/2)').simplify());
      check(Expr.parse('exp(2 * atanh(x))').simplify())
          .equals(Expr.parse('(1 + x) / (1 - x)').simplify());
      check(Expr.parse('exp(-2 * atanh(x))').simplify())
          .equals(Expr.parse('(1 - x) / (1 + x)').simplify());
      check(Expr.parse('exp(asinh(x))').simplify())
          .equals(Expr.parse('sqrt(x^2 + 1) + x').simplify());
      check(Expr.parse('exp(-asinh(x))').simplify())
          .equals(Expr.parse('sqrt(x^2 + 1) - x').simplify());
      check(Expr.parse('exp(acosh(x))').simplify())
          .equals(Expr.parse('x + sqrt(x^2 - 1)').simplify());
      check(Expr.parse('exp(-acosh(x))').simplify())
          .equals(Expr.parse('x - sqrt(x^2 - 1)').simplify());
    });

    test('denests square-root radicals sqrt(a +- b*sqrt(c))', () {
      check(Expr.parse('sqrt(3 + 2*sqrt(2))').simplify())
          .equals(Expr.parse('1 + sqrt(2)').simplify());
      check(Expr.parse('sqrt(3 - 2*sqrt(2))').simplify())
          .equals(Expr.parse('sqrt(2) - 1').simplify());
      check(Expr.parse('sqrt(5 + 2*sqrt(6))').simplify())
          .equals(Expr.parse('sqrt(2) + sqrt(3)').simplify());
      check(Expr.parse('sqrt(7 - 4*sqrt(3))').simplify())
          .equals(Expr.parse('2 - sqrt(3)').simplify());
      check(Expr.parse('sqrt(3/2 + sqrt(2))').simplify())
          .equals(Expr.parse('1 + sqrt(2)/2').simplify());
      // Non-denestable stays as Pow
      check(Expr.parse('sqrt(2 + sqrt(2))').simplify()).isA<Pow>();
    });

    test('reduces beta(x, n) for small positive integer n', () {
      check(Expr.parse('beta(x, 3)').simplify())
          .equals(Expr.parse('2 / (x * (x + 1) * (x + 2))').simplify());
    });
  });
}
