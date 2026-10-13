import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('OrderTerm - AST Representation & Contracts', () {
    test('instantiation and defaults', () {
      const o1 = OrderTerm('x', 3);
      check(o1.variable).equals('x');
      check(o1.order).equals(3);
      check(o1.point).equals(RationalNumber.zero);

      const o2 = OrderTerm('x', 2, point: RationalNumber(1));
      check(o2.variable).equals('x');
      check(o2.order).equals(2);
      check(o2.point).equals(const RationalNumber(1));
    });

    test('dependsOn and freeVariables', () {
      const o1 = OrderTerm('x', 2);
      check(o1.dependsOn('x')).isTrue();
      check(o1.dependsOn('y')).isFalse();
      check(o1.freeVariables).unorderedEquals({'x'});

      const o2 = OrderTerm('x', 2, point: y);
      check(o2.dependsOn('x')).isTrue();
      check(o2.dependsOn('y')).isTrue();
      check(o2.dependsOn('z')).isFalse();
      check(o2.freeVariables).unorderedEquals({'x', 'y'});
    });

    test('substitute', () {
      const o1 = OrderTerm('x', 2);
      final subbed1 = o1.substitute('x', const Variable('z'));
      check(subbed1).equals(const OrderTerm('z', 2));

      final subbed2 = o1.substitute('y', const Variable('z'));
      check(subbed2).equals(const OrderTerm('x', 2));

      const o3 = OrderTerm('x', 2, point: y);
      final subbed3 = o3.substitute('y', const RationalNumber(5));
      check(subbed3).equals(const OrderTerm('x', 2, point: RationalNumber(5)));
    });

    test('equality and hashCode', () {
      const a = OrderTerm('x', 2);
      const b = OrderTerm('x', 2);
      const c = OrderTerm('x', 3);
      const d = OrderTerm('y', 2);
      const e = OrderTerm('x', 2, point: RationalNumber.one);

      check(a == b).isTrue();
      check(a.hashCode).equals(b.hashCode);

      check(a == c).isFalse();
      check(a == d).isFalse();
      check(a == e).isFalse();
    });

    test('evaluation returns zero', () {
      const o = OrderTerm('x', 3);
      check(o.evaluate({'x': 10.0})).equals(0.0);
      check(o.evaluateComplex({'x': const Complex(2, 3)})).equals(Complex.zero);
    });

    test('removeOrder strips all OrderTerm leaves', () {
      const o = OrderTerm('x', 2);
      check(o.removeOrder()).equals(RationalNumber.zero);

      final expr1 = x + o;
      check(expr1.removeOrder()).equals(x);

      final expr2 =
          (const Pow(x, RationalNumber(2)) + const RationalNumber(2) * x + o)
              .removeOrder();
      check(expr2.toString()).equals('x ^ 2 + 2 * x');

      final expr3 = (const Sin(x) + o).removeOrder();
      check(expr3).equals(const Sin(x));
    });
  });

  group('OrderTerm - Textualization', () {
    test('toString formatting at origin', () {
      check(const OrderTerm('x', 0).toString()).equals('O(1)');
      check(const OrderTerm('x', 1).toString()).equals('O(x)');
      check(const OrderTerm('x', 3).toString()).equals('O(x^3)');
      check(const OrderTerm('x', -2).toString()).equals('O(x^-2)');
    });

    test('toString formatting with shifted center', () {
      check(const OrderTerm('x', 1, point: RationalNumber(1)).toString())
          .equals('O(x - 1)');
      check(const OrderTerm('x', 2, point: RationalNumber(1)).toString())
          .equals('O((x - 1)^2)');
    });

    test('toLatex formatting', () {
      check(const OrderTerm('x', 0).toLatex()).equals('O(1)');
      check(const OrderTerm('x', 1).toLatex()).equals('O(x)');
      check(const OrderTerm('x', 3).toLatex()).equals('O(x^{3})');
      check(const OrderTerm('x', 1, point: RationalNumber(2)).toLatex())
          .equals('O(x - 2)');
      check(const OrderTerm('x', 2, point: RationalNumber(2)).toLatex())
          .equals('O((x - 2)^{2})');
    });

    test('toMathMl formatting', () {
      check(const OrderTerm('x', 0).toMathMl()).equals(
        '<math><mrow><mi>O</mi><mo>(</mo><mn>1</mn><mo>)</mo></mrow></math>',
      );
      check(const OrderTerm('x', 1).toMathMl()).equals(
        '<math><mrow><mi>O</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const OrderTerm('x', 2).toMathMl()).equals(
        '<math><mrow><mi>O</mi><mo>(</mo><msup><mi>x</mi><mn>2</mn></msup><mo>)</mo></mrow></math>',
      );
    });
  });

  group('OrderTerm - Calculus & Compilation', () {
    test('differentiation order degradation', () {
      const o = OrderTerm('x', 3);
      check(o.derivative('x')).equals(const OrderTerm('x', 2));
      check(o.derivative('y')).equals(RationalNumber.zero);

      const oCentered = OrderTerm('x', 2, point: RationalNumber(1));
      check(oCentered.derivative('x'))
          .equals(const OrderTerm('x', 1, point: RationalNumber(1)));
    });

    test('fast evaluator compilation', () {
      final expr = x + const OrderTerm('x', 2);
      final fn = expr.toFunction1D('x');
      check(fn(2.0)).equals(2.0);

      final complexFn = expr.toComplexFunction1D('x');
      check(complexFn(const Complex(3, 4))).equals(const Complex(3, 4));

      final contextFn = expr.compileComplex();
      check(contextFn({'x': const Complex(3, 4)})).equals(const Complex(3, 4));
    });

    test('tensor kernel compilation', () {
      final expr = x * 2 + const OrderTerm('x', 2);
      final kernel = expr.compileTensorKernel(['x']);
      final input = Float64List.fromList([3.0]);
      final output = Float64List(1);
      kernel([input], output);
      check(output[0]).equals(6.0);
    });
  });

  group('OrderTerm - Landau Absorption Algebra', () {
    test('additive absorption min(m, n)', () {
      const o2 = OrderTerm('x', 2);
      const o3 = OrderTerm('x', 3);

      check((o3 + o2).simplify()).equals(o2);
      check((o2 + o3).simplify()).equals(o2);
      check((o3 - o2).simplify()).equals(o2);
      check((-o3).simplify()).equals(o3);
    });

    test('polynomial term absorption', () {
      const o2 = OrderTerm('x', 2);

      // x^3 + O(x^2) => O(x^2)
      check((const Pow(x, RationalNumber(3)) + o2).simplify()).equals(o2);

      // x^2 + O(x^2) => O(x^2)
      check((x * x + o2).simplify()).equals(o2);

      // x + O(x^2) preserves lower degree term
      check((x + o2).simplify()).equals(x + o2);

      // 1 + x + x^2 + x^3 + O(x^2) => x + 1 + O(x^2)
      final poly =
          (RationalNumber.one +
                  x +
                  x * x +
                  const Pow(x, RationalNumber(3)) +
                  o2)
              .simplify();
      check(poly).equals(x + 1 + o2);
    });

    test('constant absorption', () {
      const o0 = OrderTerm('x', 0);
      check((const RationalNumber(5) + o0).simplify()).equals(o0);

      const o1 = OrderTerm('x', 1);
      check((const RationalNumber(5) + o1).simplify())
          .equals(const RationalNumber(5) + o1);
    });

    test('multiplicative constant scaling', () {
      const o2 = OrderTerm('x', 2);

      check((const RationalNumber(3) * o2).simplify()).equals(o2);
      check((o2 * const RationalNumber(-2)).simplify()).equals(o2);
      check((RationalNumber.zero * o2).simplify()).equals(RationalNumber.zero);
      check((o2 * RationalNumber.zero).simplify()).equals(RationalNumber.zero);
      check((o2 / const RationalNumber(2)).simplify()).equals(o2);
    });

    test('term product and monomial scaling', () {
      const o2 = OrderTerm('x', 2);

      // x * O(x^2) => O(x^3)
      check((x * o2).simplify()).equals(const OrderTerm('x', 3));
      check((o2 * x).simplify()).equals(const OrderTerm('x', 3));

      // x^2 * O(x^2) => O(x^4)
      check((x * x * o2).simplify()).equals(const OrderTerm('x', 4));

      // (2 * x) * O(x^2) => O(x^3)
      check(((const RationalNumber(2) * x) * o2).simplify())
          .equals(const OrderTerm('x', 3));

      // (x - 1) * O((x - 1)^2) => O((x - 1)^3)
      const oShifted = OrderTerm('x', 2, point: RationalNumber(1));
      final delta = x - 1;
      check((delta * oShifted).simplify())
          .equals(const OrderTerm('x', 3, point: RationalNumber(1)));
    });

    test('order product O(x^m) * O(x^n) => O(x^(m+n))', () {
      const o2 = OrderTerm('x', 2);
      const o3 = OrderTerm('x', 3);

      check((o2 * o3).simplify()).equals(const OrderTerm('x', 5));
      check(((RationalNumber.one + x) * o2).simplify()).equals(o2);
    });

    test('power rule (O(x^m))^k => O(x^(m*k))', () {
      const o2 = OrderTerm('x', 2);

      check(o2.pow(3).simplify()).equals(const OrderTerm('x', 6));
      check(o2.pow(1).simplify()).equals(o2);
      check(o2.pow(0).simplify()).equals(RationalNumber.one);
    });

    test('expansion pipeline preserves Landau order', () {
      final expr = (x + 1) * const OrderTerm('x', 2);
      check(expr.expand()).equals(const OrderTerm('x', 2));
    });

    test('parser round-trip with OrderTerm', () {
      final p1 = Expr.parse('O(x)');
      check(p1).equals(const OrderTerm('x', 1));

      final p2 = Expr.parse('O(x^3)');
      check(p2).equals(const OrderTerm('x', 3));

      final p3 = Expr.parse('1 + x + O(x^2)');
      check(p3.removeOrder()).equals(RationalNumber.one + x);
    });

    test('adversarial Landau absorption contracts', () {
      const o3 = OrderTerm('x', 3);
      const o5 = OrderTerm('x', 5);
      const o2 = OrderTerm('x', 2);

      // O(x^3) + O(x^5) = O(x^3)
      check((o3 + o5).simplify()).equals(o3);
      check((o5 + o3).simplify()).equals(o3);

      // x^4 + O(x^2) = O(x^2)
      check((const Pow(x, RationalNumber(4)) + o2).simplify()).equals(o2);
      check((o2 + const Pow(x, RationalNumber(4))).simplify()).equals(o2);

      // c * O(x^2) = O(x^2) for c != 0
      check((const RationalNumber(7) * o2).simplify()).equals(o2);
      check((o2 * const RationalNumber(-5)).simplify()).equals(o2);
      check((const RealNumber(2.5) * o2).simplify()).equals(o2);

      // x^2 * O(x^3) = O(x^5)
      check((const Pow(x, RationalNumber(2)) * o3).simplify())
          .equals(const OrderTerm('x', 5));
      check((o3 * const Pow(x, RationalNumber(2))).simplify())
          .equals(const OrderTerm('x', 5));
      check((x * x * o3).simplify()).equals(const OrderTerm('x', 5));

      // (O(x^2))^3 = O(x^6)
      check(o2.pow(3).simplify()).equals(const OrderTerm('x', 6));
      check(const Pow(o2, RationalNumber(3)).simplify())
          .equals(const OrderTerm('x', 6));
    });
  });
}
