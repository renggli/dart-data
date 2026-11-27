import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Elementary functions', () {
    test(
      'evaluate, substitute, mapChildren, and equality for all functions',
      () {
        const x = Variable('x');
        const y = Variable('y');
        final builders = <(Expr Function(Expr), double, double)>[
          (Fn.sin.call, 0.5, math.sin(0.5)),
          (Fn.cos.call, 0.5, math.cos(0.5)),
          (Fn.tan.call, 0.5, math.tan(0.5)),
          (Fn.asin.call, 0.5, math.asin(0.5)),
          (Fn.acos.call, 0.5, math.acos(0.5)),
          (Fn.atan.call, 0.5, math.atan(0.5)),
          (Fn.sinh.call, 0.5, (math.exp(0.5) - math.exp(-0.5)) / 2),
          (Fn.cosh.call, 0.5, (math.exp(0.5) + math.exp(-0.5)) / 2),
          (Fn.tanh.call, 0.5, (math.exp(1.0) - 1) / (math.exp(1.0) + 1)),
          (Fn.asinh.call, 0.5, math.log(0.5 + math.sqrt(1.25))),
          (Fn.acosh.call, 2.0, math.log(2.0 + math.sqrt(3.0))),
          (Fn.atanh.call, 0.5, 0.5 * math.log(3.0)),
          (Fn.abs.call, -2.5, 2.5),
          (Fn.ln.call, math.e, 1.0),
        ];

        for (final (build, input, expected) in builders) {
          final node = build(x);
          check(node.evaluate({'x': input})).isCloseTo(expected, 1e-12);
          check(node.substitute('x', y)).equals(build(y));
          check(node.mapChildren((_) => y)).equals(build(y));
          check(node.freeVariables).unorderedEquals(['x']);
          check(node.dependsOn('x')).isTrue;
          check(node.dependsOn('y')).isFalse;
          check(node.anyNode((e) => e == x)).isTrue;
          check(node).equals(build(x));
          check(node.hashCode).equals(build(x).hashCode);
        }
      },
    );
  });

  group('Hyperbolic and inverse hyperbolic boundary cases', () {
    test('saturation, asymptotic domains, and NaN/infinity boundaries', () {
      const x = Variable('x');
      check(Fn.tanh(x).evaluate({'x': 25.0})).equals(1.0);
      check(Fn.tanh(x).evaluate({'x': -25.0})).equals(-1.0);

      check(Fn.asinh(x).evaluate({'x': double.nan}).isNaN).isTrue;
      check(Fn.asinh(x).evaluate({'x': double.infinity}))
          .equals(double.infinity);
      check(Fn.asinh(x).evaluate({'x': -1e10}))
          .isCloseTo(-(math.log(1e10) + math.ln2), 1e-12);

      check(Fn.acosh(x).evaluate({'x': 0.5}).isNaN).isTrue;
      check(Fn.acosh(x).evaluate({'x': 1e10}))
          .isCloseTo(math.log(1e10) + math.ln2, 1e-12);

      check(Fn.atanh(x).evaluate({'x': -1.5}).isNaN).isTrue;
      check(Fn.atanh(x).evaluate({'x': 1.5}).isNaN).isTrue;
      check(Fn.atanh(x).evaluate({'x': 1.0})).equals(double.infinity);
      check(Fn.atanh(x).evaluate({'x': -1.0})).equals(double.negativeInfinity);

      final sinhVal = Fn.sinh(const RealNumber(1.2)).evaluate();
      final coshVal = Fn.cosh(const RealNumber(1.2)).evaluate();
      final tanhVal = Fn.tanh(const RealNumber(0.6)).evaluate();
      check(Fn.asinh(x).evaluate({'x': sinhVal})).isCloseTo(1.2, 1e-12);
      check(Fn.acosh(x).evaluate({'x': coshVal})).isCloseTo(1.2, 1e-12);
      check(Fn.atanh(x).evaluate({'x': tanhVal})).isCloseTo(0.6, 1e-12);
      check(Fn.asinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.acosh(IntegerNumber.one).simplify()).equals(IntegerNumber.zero);
      check(Fn.atanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.asinh(-x).simplify()).equals(-Fn.asinh(x));
      check(Fn.atanh(-x).simplify()).equals(-Fn.atanh(x));
    });
  });

  group('Complex-part functions and normal forms', () {
    test('re, im, arg, and conj simplification, formatting, and evaluation', () {
      const x = Variable('x');
      const z = Variable('z');

      check(Expr.parse('re(3 + 4 * i)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('im(3 + 4 * i)').simplify()).equals(IntegerNumber.of(4));
      check(Expr.parse('conj(3 + 4 * i)').simplify())
          .equals(Expr.parse('3 - 4 * i').simplify());
      check(Expr.parse('abs(3 + 4 * i)').simplify())
          .equals(IntegerNumber.of(5));
      check(Expr.parse('arg(1 + i)').simplify().toString()).equals('1/4 * pi');
      check(Expr.parse('arg(-1)').simplify()).equals(Constant.pi);
      check(Expr.parse('arg(i)').simplify().toString()).equals('1/2 * pi');
      check(Expr.parse('arg(-i)').simplify().toString()).equals('-1/2 * pi');

      check(Fn.re(x).simplify(assumptions: Assumptions.real)).equals(x);
      check(Fn.im(x).simplify(assumptions: Assumptions.real))
          .equals(IntegerNumber.zero);
      check(Fn.conj(x).simplify(assumptions: Assumptions.real)).equals(x);
      check(
        Expr.parse('re(exp(i * x))').simplify(assumptions: Assumptions.real),
      ).equals(Fn.cos(x));
      check(
        Expr.parse('im(exp(i * x))').simplify(assumptions: Assumptions.real),
      ).equals(Fn.sin(x));
      check(
        Expr.parse('abs(exp(i * x))').simplify(assumptions: Assumptions.real),
      ).equals(IntegerNumber.one);

      const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
      check(Fn.re(z).simplify(assumptions: complexZ)).equals(Fn.re(z));
      check(Fn.im(z).simplify(assumptions: complexZ)).equals(Fn.im(z));
      check(Fn.conj(z).simplify(assumptions: complexZ)).equals(Fn.conj(z));
      check(Fn.conj(Fn.conj(z)).simplify(assumptions: complexZ)).equals(z);
      check(Fn.re(Fn.conj(z)).simplify(assumptions: complexZ)).equals(Fn.re(z));
      check(Fn.im(Fn.conj(z)).simplify(assumptions: complexZ))
          .equals((-Fn.im(z)).simplify(assumptions: complexZ));

      for (final source in ['re(z)', 'im(z)', 'arg(z)', 'conj(z)']) {
        final parsed = Expr.parse(source);
        check(Expr.parse(parsed.toString())).equals(parsed);
      }
      check(Fn.re(z).toLatex()).equals(r'\operatorname{Re}(z)');
      check(Fn.im(z).toLatex()).equals(r'\operatorname{Im}(z)');
      check(Fn.arg(z).toLatex()).equals(r'\arg(z)');
      check(Fn.conj(z).toLatex()).equals(r'\overline{z}');
      check(Fn.conj(z).toMathMl()).equals(
        '<math><mover><mrow><mi>z</mi></mrow><mo>&#x00AF;</mo></mover></math>',
      );

      check(Fn.abs(x).isReal).isTrue;
      check(Fn.re(x).isReal).isTrue;
      check(Fn.im(x).isReal).isTrue;
      check(Fn.arg(x).isReal).isTrue;
      check(
        Fn.abs(ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)))
            .evaluate({'x': 1.0}),
      ).isCloseTo(5.0, 1e-12);
      check(Fn.re(x).evaluate({'x': 3.5})).equals(3.5);
      check(Fn.re(x + ComplexNumber.i).evaluate({'x': 3.5})).equals(3.5);
      check(Fn.im(x).evaluate({'x': 3.5})).equals(0.0);
      check(
        Fn.im(x + ComplexNumber.i * IntegerNumber.of(4)).evaluate({'x': 3.5}),
      ).equals(4.0);
      check(Fn.arg(x).evaluate({'x': -2.0})).isCloseTo(math.pi, 1e-12);
      check(Fn.conj(x).evaluate({'x': 3.5})).equals(3.5);

      check(Fn.re(x).substitute('x', z)).equals(Fn.re(z));
      check(Fn.re(x).mapChildren((_) => z)).equals(Fn.re(z));
      check(Fn.im(x).substitute('x', z)).equals(Fn.im(z));
      check(Fn.im(x).mapChildren((_) => z)).equals(Fn.im(z));
      check(Fn.arg(x).substitute('x', z)).equals(Fn.arg(z));
      check(Fn.arg(x).mapChildren((_) => z)).equals(Fn.arg(z));
      check(Fn.conj(x).substitute('x', z)).equals(Fn.conj(z));
      check(Fn.conj(x).mapChildren((_) => z)).equals(Fn.conj(z));

      final reFn = Fn.re(z).toComplexFunction1D('z');
      final imFn = Fn.im(z).toComplexFunction1D('z');
      final conjFn = Fn.conj(z).toComplexFunction1D('z');
      check(reFn(const Complex(3, 4))).equals(const Complex(3));
      check(imFn(const Complex(3, 4))).equals(const Complex(4));
      check(conjFn(const Complex(3, 4))).equals(const Complex(3, -4));
    });

    test('toRectangular and toPolar normal forms', () {
      check(
        Expr.parse('(x + i * y)^2')
            .toRectangular(assumptions: Assumptions.real)
            .toString(),
      ).equals('x ^ 2 - y ^ 2 + 2 * i * x * y');
      check(
        Expr.parse('exp(i * x)')
            .toRectangular(assumptions: Assumptions.real)
            .toString(),
      ).equals('cos(x) + i * sin(x)');
      check(
        Expr.parse('1 / (x + i * y)')
            .toRectangular(assumptions: Assumptions.real)
            .toString(),
      ).equals('(x - i * y) / (x ^ 2 + y ^ 2)');

      check(Expr.parse('1 + i').toPolar().toString())
          .equals('sqrt(2) * exp(1/4 * i * pi)');
      check(Expr.parse('-2').toPolar().toString()).equals('2 * exp(i * pi)');
      check(Expr.parse('3').toPolar()).equals(IntegerNumber.of(3));
      check(Expr.parse('0').toPolar()).equals(IntegerNumber.zero);
    });
  });
}
