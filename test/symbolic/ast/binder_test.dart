import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const k = Variable('k');
  const n = Variable('n');
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('Derivative AST node', () {
    test('constructs first and higher order derivatives with equality', () {
      final d1 = Derivative(Fn.sin(x), 'x');
      check(d1.expr).equals(Fn.sin(x));
      check(d1.variable).equals('x');
      check(d1.order).equals(1);

      final d2 = Derivative(Fn.sin(x), 'x', order: 2);
      check(d2.order).equals(2);

      final a = Derivative(x + y, 'x', order: 2);
      final b = Derivative(x + y, 'x', order: 2);
      final c = Derivative(x + y, 'y', order: 2);
      final d = Derivative(x + y, 'x', order: 3);
      check(a).equals(b);
      check(a.hashCode).equals(b.hashCode);
      check(a == c).isFalse;
      check(a == d).isFalse;
    });

    test('evaluation, traversal, point evaluation, and alpha-renaming', () {
      final d = Derivative(Fn.sin(x), 'x');
      check(d.evaluate({'x': 1.0})).isCloseTo(math.cos(1.0), 1e-12);

      final prodD = Derivative(x * y, 'x');
      check(prodD.freeVariables).deepEquals({'x', 'y'});
      check(prodD.dependsOn('x')).isTrue;
      check(prodD.dependsOn('y')).isTrue;
      check(prodD.dependsOn('z')).isFalse;

      final dAdd = Derivative(x + y, 'x', order: 2);
      check(dAdd.substitute('y', IntegerNumber.of(5)))
          .equals(Derivative(x + IntegerNumber.of(5), 'x', order: 2));
      check(dAdd.substitute('x', z)).equals(Derivative(z + y, 'z', order: 2));
      check(dAdd.substitute('x', IntegerNumber.two)).equals(IntegerNumber.zero);
      check(dAdd.mapChildren((child) => child * IntegerNumber.two))
          .equals(Derivative((x + y) * IntegerNumber.two, 'x', order: 2));

      check(d.anyNode((node) => node is Derivative)).isTrue;
      check(d.anyNode((node) => node is Call && node.id == FunctionId.sin))
          .isTrue;
      check(d.anyNode((node) => node is Call && node.id == FunctionId.cos))
          .isFalse;

      final dQuad = Derivative(x * x, 'x');
      check(dQuad.substitute('x', IntegerNumber.two).simplify())
          .equals(IntegerNumber.of(4));

      final subRenamed = prodD.substitute('x', y) as Derivative;
      check(subRenamed.variable).equals('y');
      check(subRenamed.expr).equals(y * const Variable('y_1'));

      final subFree = prodD.substitute('y', x) as Derivative;
      check(subFree.variable).equals('x_1');
      check(subFree.expr).equals(const Variable('x_1') * x);

      final dZeta = Derivative(Fn.zeta(x), 'x');
      check(dZeta.substitute('x', IntegerNumber.two))
          .equals(Derivative(Fn.zeta(x), 'x', point: IntegerNumber.two));

      final dPoint = Derivative(x * y, 'x', point: IntegerNumber.two);
      check(dPoint.dependsOn('x')).isFalse;
      check(dPoint.dependsOn('y')).isTrue;
      check(dPoint.freeVariables).deepEquals({'y'});
      check(Derivative(x * x, 'x', point: IntegerNumber.two).simplify())
          .equals(IntegerNumber.of(4));

      final dWithPoint = Derivative(x * y, 'x', point: y);
      check(dWithPoint.substitute('y', IntegerNumber.of(3))).equals(
        Derivative(x * IntegerNumber.of(3), 'x', point: IntegerNumber.of(3)),
      );
      check(Derivative(x * y, 'x', point: x).substitute('x', IntegerNumber.two))
          .equals(Derivative(x * y, 'x', point: IntegerNumber.two));
      final subPointCapture =
          Derivative(x * y, 'x', point: y).substitute('y', x) as Derivative;
      check(subPointCapture.variable).equals('x_1');
      check(subPointCapture.point).equals(x);
    });
  });

  group('Integral AST node', () {
    test(
      'indefinite and definite properties, substitution, and quadrature',
      () {
        const t = Variable('t');
        const a = Variable('a');
        final indef = Integral(a * t, 't');

        check(indef.isDefinite).isFalse;
        check(indef.evaluate({'a': 1.0, 't': 2.0}).isNaN).isTrue;
        check(indef.freeVariables).unorderedEquals(['a', 't']);
        check(indef.dependsOn('t')).isTrue;
        check(indef.dependsOn('a')).isTrue;
        check(indef.dependsOn('z')).isFalse;
        check(indef.substitute('a', IntegerNumber.two))
            .equals(Integral(IntegerNumber.two * t, 't'));
        check(indef.substitute('t', y)).equals(Integral(a * y, 'y'));
        check(indef.substitute('t', a)).equals(indef);
        check(indef.substitute('t', IntegerNumber.two)).equals(indef);
        final alphaRenamed = indef.substitute('a', t) as Integral;
        check(alphaRenamed.variable).not(.it()..equals('t'));
        check(alphaRenamed.dependsOn('t')).isTrue;
        check(indef.mapChildren((e) => e)).equals(indef);
        check(indef.anyNode((e) => e == a)).isTrue;
        check(indef.hashCode).equals(Integral(a * t, 't').hashCode);

        final defParam = Integral(
          t * x,
          't',
          lower: IntegerNumber.zero,
          upper: x,
        );
        check(defParam.isDefinite).isTrue;
        check(defParam.freeVariables).unorderedEquals(['x']);
        check(defParam.dependsOn('t')).isFalse;
        check(defParam.dependsOn('x')).isTrue;
        check(defParam.substitute('t', IntegerNumber.of(5))).equals(defParam);
        check(defParam.substitute('t', const Variable('u'))).equals(defParam);

        final defConflict = Integral(
          t * const Variable('u'),
          't',
          lower: IntegerNumber.zero,
          upper: t,
        );
        check(defConflict.substitute('t', const Variable('u'))).equals(
          Integral(
            t * const Variable('u'),
            't',
            lower: IntegerNumber.zero,
            upper: const Variable('u'),
          ),
        );
        check(defParam.substitute('x', IntegerNumber.two)).equals(
          Integral(
            t * IntegerNumber.two,
            't',
            lower: IntegerNumber.zero,
            upper: IntegerNumber.two,
          ),
        );

        final subAlpha =
            defParam.substitute('x', t + IntegerNumber.one) as Integral;
        check(subAlpha.variable).equals('t_1');
        check(subAlpha).equals(
          Integral(
            const Variable('t_1') * (t + IntegerNumber.one),
            't_1',
            lower: IntegerNumber.zero,
            upper: t + IntegerNumber.one,
          ),
        );
        check(defParam.mapChildren((e) => e)).equals(defParam);
        check(defParam.anyNode((e) => e == IntegerNumber.zero)).isTrue;
        check(defParam.anyNode((e) => e == z)).isFalse;

        check(
          Integral(
            Pow.of(t, IntegerNumber.two),
            't',
            lower: IntegerNumber.zero,
            upper: IntegerNumber.of(3),
          ).evaluate(),
        ).isCloseTo(9.0, 1e-12);
        check(
          Integral(
            Pow.of(t, IntegerNumber.two),
            't',
            lower: IntegerNumber.of(3),
            upper: IntegerNumber.zero,
          ).evaluate(),
        ).isCloseTo(-9.0, 1e-12);
        check(
          Integral(
            Pow.of(t, IntegerNumber.two),
            't',
            lower: IntegerNumber.two,
            upper: IntegerNumber.two,
          ).evaluate(),
        ).equals(0.0);
        check(
          Integral(
            t,
            't',
            lower: Constant.undefined,
            upper: IntegerNumber.one,
          ).evaluate().isNaN,
        ).isTrue;
        check(
          Integral(
            Pow.of(Constant.e, -t),
            't',
            lower: IntegerNumber.zero,
            upper: Constant.infinity,
          ).evaluate(),
        ).isCloseTo(1.0, 1e-5);
        check(
          Integral(
            Pow.of(Constant.e, t),
            't',
            lower: -Constant.infinity,
            upper: IntegerNumber.zero,
          ).evaluate(),
        ).isCloseTo(1.0, 1e-5);
        check(
          Integral(
            Pow.of(Constant.e, -Pow.of(t, IntegerNumber.two)),
            't',
            lower: -Constant.infinity,
            upper: Constant.infinity,
          ).evaluate(),
        ).isCloseTo(math.sqrt(math.pi), 1e-3);
      },
    );
  });

  group('Limit AST node', () {
    test('construction, equality, substitution, and evaluation', () {
      final lim = Limit(Fn.sin(x) / x, 'x', IntegerNumber.zero);
      check(lim.expr).equals(Fn.sin(x) / x);
      check(lim.variable).equals('x');
      check(lim.point).equals(IntegerNumber.zero);
      check(lim.direction).equals(LimitDirection.both);
      check(lim.evaluate({'x': 1.0})).isCloseTo(1.0, 1e-12);

      final a = Limit(
        x + y,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromBelow,
      );
      final b = Limit(
        x + y,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromBelow,
      );
      final c = Limit(
        x + y,
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromAbove,
      );
      final d = Limit(
        x + y,
        'x',
        IntegerNumber.one,
        direction: LimitDirection.fromBelow,
      );
      check(a).equals(b);
      check(a.hashCode).equals(b.hashCode);
      check(a == c).isFalse;
      check(a == d).isFalse;

      final freeLim = Limit(x * y, 'x', z);
      check(freeLim.freeVariables).deepEquals({'y', 'z'});
      check(freeLim.dependsOn('x')).isFalse;
      check(freeLim.dependsOn('y')).isTrue;
      check(freeLim.dependsOn('z')).isTrue;
      check(freeLim.dependsOn('w')).isFalse;
      check(Limit(x * y, 'x', x).dependsOn('x')).isTrue;

      final subLim = Limit(x + y, 'x', y);
      check(subLim.substitute('y', IntegerNumber.two))
          .equals(Limit(x + IntegerNumber.two, 'x', IntegerNumber.two));
      check(subLim.substitute('x', IntegerNumber.two)).equals(subLim);
      final subAlpha = subLim.substitute('y', x + IntegerNumber.one) as Limit;
      check(subAlpha.variable).equals('x_1');
      check(subAlpha.point).equals(x + IntegerNumber.one);
      check(subAlpha.expr)
          .equals(Add.of([const Variable('x_1'), x + IntegerNumber.one]));

      final sinLim = Limit(
        Fn.sin(x),
        'x',
        IntegerNumber.zero,
        direction: LimitDirection.fromAbove,
      );
      check(sinLim.mapChildren((child) => child + IntegerNumber.one)).equals(
        Limit(
          Fn.sin(x) + IntegerNumber.one,
          'x',
          IntegerNumber.one,
          direction: LimitDirection.fromAbove,
        ),
      );
      check(sinLim.anyNode((node) => node is Limit)).isTrue;
      check(sinLim.anyNode((node) => node is Call && node.id == FunctionId.sin))
          .isTrue;
      check(sinLim.anyNode((node) => node is IntegerNumber)).isTrue;
      check(sinLim.anyNode((node) => node is Call && node.id == FunctionId.cos))
          .isFalse;
    });
  });

  group('Piecewise AST node', () {
    test('evaluation, traversal, simplification, and immutability', () {
      final pw = Expr.parse('piecewise(x < -1, -1, x > 1, 1, x)');
      check(pw).isA<Piecewise>();
      check(pw.evaluate({'x': -5.0})).equals(-1.0);
      check(pw.evaluate({'x': 0.25})).equals(0.25);
      check(pw.evaluate({'x': 5.0})).equals(1.0);

      final partial = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: y),
      ]);
      check(partial.evaluate({'x': -1.0, 'y': 4.0})).equals(4.0);
      check(partial.evaluate({'x': 1.0, 'y': 4.0}).isNaN).isTrue;
      check(partial.freeVariables).unorderedEquals(['x', 'y']);
      check(partial.dependsOn('x')).isTrue;
      check(partial.dependsOn('y')).isTrue;
      check(partial.dependsOn('z')).isFalse;
      check(partial.mapChildren((e) => e)).equals(partial);
      check(partial.anyNode((e) => e == y)).isTrue;
      check(partial.anyNode((e) => e == z)).isFalse;

      final withOtherwise = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: y),
      ], otherwise: z);
      check(withOtherwise.freeVariables).unorderedEquals(['x', 'y', 'z']);
      check(withOtherwise.dependsOn('z')).isTrue;
      check(withOtherwise.mapChildren((e) => e)).equals(withOtherwise);
      check(withOtherwise.anyNode((e) => e == withOtherwise)).isTrue;
      check(withOtherwise.anyNode((e) => e == z)).isTrue;
      check(withOtherwise == partial).isFalse;
      check(
        withOtherwise ==
            Piecewise([
              (relation: Relational.lessThan(x, IntegerNumber.zero), expr: x),
            ], otherwise: z),
      ).isFalse;

      check(pw.substitute('x', IntegerNumber.of(-3)).simplify())
          .equals(IntegerNumber.negativeOne);
      check(pw.substitute('x', IntegerNumber.zero).simplify())
          .equals(IntegerNumber.zero);
      check(pw.substitute('x', IntegerNumber.of(3)).simplify())
          .equals(IntegerNumber.one);

      final mutableBranches = <PiecewiseBranch>[
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: y),
      ];
      final pwUnmodifiable = Piecewise(mutableBranches);
      mutableBranches.add((
        relation: Relational.greaterThan(x, IntegerNumber.zero),
        expr: z,
      ));
      check(pwUnmodifiable.branches.length).equals(1);
      check(
        () => pwUnmodifiable.branches.add((
          relation: Relational.greaterThan(x, IntegerNumber.zero),
          expr: z,
        )),
      ).throws<UnsupportedError>();
    });
  });

  group('RootSum AST node', () {
    test(
      'properties, substitution, parsing, differentiation, and evaluation',
      () {
        const t = Variable('t');
        final rs1 = RootSum(t.pow(3) - t - x, 't', Fn.ln(x - t));
        final rs2 = RootSum(t.pow(3) - t - x, 't', Fn.ln(x - t));
        final rsDiffVar = RootSum(
          const Variable('u').pow(3) - const Variable('u') - x,
          'u',
          Fn.ln(x - const Variable('u')),
        );

        check(rs1.freeVariables).deepEquals({'x'});
        check(rs1.anyNode((node) => node is Call && node.id == FunctionId.ln))
            .isTrue;
        check(rs1.anyNode((node) => node is Call && node.id == FunctionId.sin))
            .isFalse;
        check(rs1).equals(rs2);
        check(rs1.hashCode).equals(rs2.hashCode);
        check(rs1 == rsDiffVar).isFalse;

        final rs = RootSum(t.pow(2) - x, 't', x + t);
        check(identical(rs.mapChildren((e) => e), rs)).isTrue;
        check(rs.substitute('t', IntegerNumber.of(5))).equals(rs);
        final replaced = rs.substitute('x', t + y) as RootSum;
        check(replaced.variable == 't').isFalse;
        check(replaced.freeVariables).deepEquals({'t', 'y'});
        check(replaced.evaluate({'t': 1.0, 'y': 3.0})).isCloseTo(8.0, 1e-9);

        final a = Expr.parse('rootsum(t^2 - 1, t, t)');
        final b = Expr.parse('rootsum(t^2 - 2, t, t)');
        check(a + b).isA<Add>();

        final parsed = Expr.parse('rootsum(t^3 - 2, t, ln(x - t))');
        check(parsed).isA<RootSum>();
        check(parsed.toString()).equals('rootsum(-2 + t ^ 3, t, ln(-t + x))');
        final simplified = parsed.simplify();
        check(simplified.toLatex())
            .equals(r'\sum_{t : -2 + {t}^{3} = 0} \ln(-t + x)');
        check(simplified.toMathMl()).contains('<munder>');

        final unboundE = Expr.parse('rootsum(e^2 - 1, e, e)');
        check(unboundE.freeVariables).isEmpty;
        check(unboundE.evaluate()).isCloseTo(0.0, 1e-12);
        check(() => Expr.parse('rootsum(t^2 - 1, t)'))
            .throws<FormatException>();
        check(() => Expr.parse('rootsum(t^2 - 1, 2, t)'))
            .throws<FormatException>();

        check(Expr.parse('rootsum(t^3 - 1, t, 0)').simplify())
            .equals(IntegerNumber.zero);
        check(Expr.parse('rootsum(5, t, t)').simplify())
            .equals(IntegerNumber.zero);
        check(Expr.parse('rootsum(t - 3, t, t^2 + 1)').simplify())
            .equals(IntegerNumber.of(10));
        check(Expr.parse('rootsum(t^4 + t + 1, t, x)').simplify())
            .equals(Expr.parse('4 * x').simplify());
        check(Expr.parse('rootsum(t^3 - 2, t, t)').simplify()).isA<RootSum>();

        final param = Expr.parse('rootsum(t^2 - x, t, t^3)');
        check(param.derivative('x').evaluate({'x': 4.0})).isCloseTo(0.0, 1e-9);
        check(Expr.parse('rootsum(x^2 - 2, x, x)').derivative('x'))
            .equals(IntegerNumber.zero);

        final blakeIntegral = Expr.parse(
          '1/8*rootsum(_Z1^8 - 4*_Z1^4 + 2, _Z1, (-ln(x) + ln((x^4 + 1)^(1/2) - x*_Z1))/_Z1)',
        );
        final blakeIntegrand = Expr.parse(
          '(x^16 - 1) / (x^4 + 1)^(1/2) / (x^16 + 1)',
        );
        final deriv = blakeIntegral.derivative('x').evaluateComplex({
          'x': const Complex(1.3),
        });
        final expected = blakeIntegrand.evaluateComplex({
          'x': const Complex(1.3),
        });
        check(deriv.a).isCloseTo(expected.a, 1e-8);
        check(deriv.b).isCloseTo(expected.b, 1e-8);

        final realRoots = Expr.parse('rootsum(t^2 - 5*t + 6, t, t^2)');
        check(realRoots.evaluate()).isCloseTo(13.0, 1e-9);
        check((realRoots.approximate() as RealNumber).value)
            .isCloseTo(13.0, 1e-9);
        check(Expr.parse('rootsum(t^2 + 1, t, t^2)').evaluate())
            .isCloseTo(-2.0, 1e-9);
        check(Expr.parse('rootsum(t^3 - a*t - 1, t, t^2)').evaluate({'a': 3.5}))
            .isCloseTo(7.0, 1e-9);
        final complexVal = Expr.parse('rootsum(t^3 - i, t, t^3)')
            .evaluateComplex();
        check(complexVal.a).isCloseTo(0.0, 1e-9);
        check(complexVal.b).isCloseTo(3.0, 1e-9);
      },
    );
  });

  group('Sum and Product AST nodes', () {
    test('Sum properties, substitution, copyWith, and equality', () {
      final sum = Sum(k * k, 'k', IntegerNumber.one, n);
      check(sum.variable).equals('k');
      check(sum.lower).equals(IntegerNumber.one);
      check(sum.upper).equals(n);
      check(sum.freeVariables).unorderedEquals(['n']);
      check(identical(sum.freeVariables, sum.freeVariables)).isTrue;
      check(sum.dependsOn('n')).isTrue;
      check(sum.dependsOn('k')).isFalse;
      check(sum.dependsOn('x')).isFalse;
      check(sum.anyNode((e) => e == n)).isTrue;
      check(sum.anyNode((e) => e == IntegerNumber.one)).isTrue;
      check(sum.anyNode((e) => e == const Variable('nonexistent'))).isFalse;

      final plainSum = Sum(k, 'k', IntegerNumber.one, n);
      final substituted = plainSum.substitute('n', IntegerNumber.of(10)) as Sum;
      check(substituted.upper).equals(IntegerNumber.of(10));

      final subAlpha = plainSum.substitute('n', k + IntegerNumber.one) as Sum;
      check(subAlpha.variable).equals('k_1');
      check(subAlpha).equals(
        Sum(
          const Variable('k_1'),
          'k_1',
          IntegerNumber.one,
          k + IntegerNumber.one,
        ),
      );

      final mapped = plainSum.mapChildren((e) => e + IntegerNumber.one) as Sum;
      check(mapped.lower).equals(IntegerNumber.two);

      final s1 = Sum(k, 'k', IntegerNumber.one, n);
      final s2 = Sum(k, 'k', IntegerNumber.one, n);
      final s3 = Sum(k * k, 'k', IntegerNumber.one, n);
      check(s1).equals(s2);
      check(s1.hashCode).equals(s2.hashCode);
      check(s1 == s3).isFalse;
    });

    test('Product properties, substitution, copyWith, and equality', () {
      final prod = Product(k, 'k', IntegerNumber.one, n);
      check(prod.variable).equals('k');
      check(prod.lower).equals(IntegerNumber.one);
      check(prod.upper).equals(n);
      check(prod.freeVariables).unorderedEquals(['n']);
      check(prod.dependsOn('n')).isTrue;
      check(prod.dependsOn('k')).isFalse;
      check(prod.anyNode((e) => e == n)).isTrue;
      check(prod.anyNode((e) => e == IntegerNumber.one)).isTrue;
      check(prod.anyNode((e) => e == const Variable('nonexistent'))).isFalse;

      final substituted = prod.substitute('n', IntegerNumber.of(20)) as Product;
      check(substituted.upper).equals(IntegerNumber.of(20));

      final mapped = prod.mapChildren((e) => e * IntegerNumber.two) as Product;
      check(mapped.lower).equals(IntegerNumber.two);

      final p2 = Product(k, 'k', IntegerNumber.one, n);
      final p3 = Product(k * k, 'k', IntegerNumber.one, n);
      check(prod).equals(p2);
      check(prod.hashCode).equals(p2.hashCode);
      check(prod == p3).isFalse;
    });
  });
}
