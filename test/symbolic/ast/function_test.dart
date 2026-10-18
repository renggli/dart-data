import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Elementary functions', () {
    test(
      'evaluate, substitute, mapChildren, and equality for all functions',
      () {
        const x = Variable('x');
        const y = Variable('y');
        final builders = <(Expr Function(Expr), double, double)>[
          (Sin.new, 0.5, math.sin(0.5)),
          (Cos.new, 0.5, math.cos(0.5)),
          (Tan.new, 0.5, math.tan(0.5)),
          (Asin.new, 0.5, math.asin(0.5)),
          (Acos.new, 0.5, math.acos(0.5)),
          (Atan.new, 0.5, math.atan(0.5)),
          (Sinh.new, 0.5, (math.exp(0.5) - math.exp(-0.5)) / 2),
          (Cosh.new, 0.5, (math.exp(0.5) + math.exp(-0.5)) / 2),
          (Tanh.new, 0.5, (math.exp(1.0) - 1) / (math.exp(1.0) + 1)),
          (Asinh.new, 0.5, math.log(0.5 + math.sqrt(1.25))),
          (Acosh.new, 2.0, math.log(2.0 + math.sqrt(3.0))),
          (Atanh.new, 0.5, 0.5 * math.log(3.0)),
          (Abs.new, -2.5, 2.5),
          (Ln.new, math.e, 1.0),
        ];

        for (final (build, input, expected) in builders) {
          final node = build(x);
          check(node.evaluate({'x': input})).isCloseTo(expected, 1e-12);
          check(node.substitute('x', y)).equals(build(y));
          check(node.mapChildren((_) => y)).equals(build(y));
          check(node.freeVariables).unorderedEquals(['x']);
          check(node.dependsOn('x')).isTrue();
          check(node.dependsOn('y')).isFalse();
          check(node.anyNode((e) => e == x)).isTrue();
          check(node).equals(build(x));
          check(node.hashCode).equals(build(x).hashCode);
        }
      },
    );
  });

  group('Hyperbolic and inverse hyperbolic boundary cases', () {
    test('saturation, asymptotic domains, and NaN/infinity boundaries', () {
      const x = Variable('x');
      check(Tanh(x).evaluate({'x': 25.0})).equals(1.0);
      check(Tanh(x).evaluate({'x': -25.0})).equals(-1.0);

      check(Asinh(x).evaluate({'x': double.nan}).isNaN).isTrue();
      check(Asinh(x).evaluate({'x': double.infinity})).equals(double.infinity);
      check(Asinh(x).evaluate({'x': -1e10}))
          .isCloseTo(-(math.log(1e10) + math.ln2), 1e-12);

      check(Acosh(x).evaluate({'x': 0.5}).isNaN).isTrue();
      check(Acosh(x).evaluate({'x': 1e10}))
          .isCloseTo(math.log(1e10) + math.ln2, 1e-12);

      check(Atanh(x).evaluate({'x': -1.5}).isNaN).isTrue();
      check(Atanh(x).evaluate({'x': 1.5}).isNaN).isTrue();
      check(Atanh(x).evaluate({'x': 1.0})).equals(double.infinity);
      check(Atanh(x).evaluate({'x': -1.0})).equals(double.negativeInfinity);
    });
  });

  group('Complex-part functions and normal forms', () {
    test(
      'Re, Im, Arg, and Conjugate simplification, formatting, and evaluation',
      () {
        const x = Variable('x');
        const z = Variable('z');

        check(Expr.parse('re(3 + 4 * i)').simplify())
            .equals(IntegerNumber.of(3));
        check(Expr.parse('im(3 + 4 * i)').simplify())
            .equals(IntegerNumber.of(4));
        check(Expr.parse('conj(3 + 4 * i)').simplify())
            .equals(Expr.parse('3 - 4 * i').simplify());
        check(Expr.parse('abs(3 + 4 * i)').simplify())
            .equals(IntegerNumber.of(5));
        check(Expr.parse('arg(1 + i)').simplify().toString())
            .equals('1/4 * pi');
        check(Expr.parse('arg(-1)').simplify()).equals(Constant.pi);
        check(Expr.parse('arg(i)').simplify().toString()).equals('1/2 * pi');
        check(Expr.parse('arg(-i)').simplify().toString()).equals('-1/2 * pi');

        // Real variables simplify directly
        check(Re(x).simplify()).equals(x);
        check(Im(x).simplify()).equals(IntegerNumber.zero);
        check(Conjugate(x).simplify()).equals(x);
        check(Expr.parse('re(exp(i * x))').simplify()).equals(Cos(x));
        check(Expr.parse('im(exp(i * x))').simplify()).equals(Sin(x));
        check(Expr.parse('abs(exp(i * x))').simplify())
            .equals(IntegerNumber.one);

        // Complex variable remains symbolic
        Assumptions.run(() {
          check(Re(z).simplify()).equals(Re(z, isSimplified: true));
          check(Im(z).simplify()).equals(Im(z, isSimplified: true));
          check(Conjugate(z).simplify())
              .equals(Conjugate(z, isSimplified: true));
          check(Conjugate(Conjugate(z)).simplify()).equals(z);
          check(Re(Conjugate(z)).simplify()).equals(Re(z, isSimplified: true));
          check(Im(Conjugate(z)).simplify())
              .equals((-Im(z, isSimplified: true)).simplify());
        }, domains: {'z': VariableDomain.complex});

        // Textualization and round-trip
        for (final source in ['re(z)', 'im(z)', 'arg(z)', 'conj(z)']) {
          final parsed = Expr.parse(source);
          check(Expr.parse(parsed.toString())).equals(parsed);
        }
        check(Re(z).toLatex()).equals(r'\operatorname{Re}(z)');
        check(Im(z).toLatex()).equals(r'\operatorname{Im}(z)');
        check(Arg(z).toLatex()).equals(r'\arg(z)');
        check(Conjugate(z).toLatex()).equals(r'\overline{z}');
        check(Conjugate(z).toMathMl()).equals(
          '<math><mover><mrow><mi>z</mi></mrow><mo>&macr;</mo></mover></math>',
        );

        // Direct AST methods: isReal, evaluate, substitute, mapChildren
        check(Abs(x).isReal).isTrue();
        check(Re(x).isReal).isTrue();
        check(Im(x).isReal).isTrue();
        check(Arg(x).isReal).isTrue();
        check(
          Abs(ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)))
              .evaluate({'x': 1.0}),
        ).isCloseTo(5.0, 1e-12);
        check(Re(x).evaluate({'x': 3.5})).equals(3.5);
        check(Re(x + ComplexNumber.i).evaluate({'x': 3.5})).equals(3.5);
        check(Im(x).evaluate({'x': 3.5})).equals(0.0);
        check(
          Im(x + ComplexNumber.i * IntegerNumber.of(4)).evaluate({'x': 3.5}),
        ).equals(4.0);
        check(Arg(x).evaluate({'x': -2.0})).isCloseTo(math.pi, 1e-12);
        check(Conjugate(x).evaluate({'x': 3.5})).equals(3.5);

        check(Re(x).substitute('x', z)).equals(Re(z));
        check(Re(x).mapChildren((_) => z)).equals(Re(z));
        check(Im(x).substitute('x', z)).equals(Im(z));
        check(Im(x).mapChildren((_) => z)).equals(Im(z));
        check(Arg(x).substitute('x', z)).equals(Arg(z));
        check(Arg(x).mapChildren((_) => z)).equals(Arg(z));
        check(Conjugate(x).substitute('x', z)).equals(Conjugate(z));
        check(Conjugate(x).mapChildren((_) => z)).equals(Conjugate(z));

        // Bytecode compilation
        final reFn = Re(z).toComplexFunction1D('z');
        final imFn = Im(z).toComplexFunction1D('z');
        final conjFn = Conjugate(z).toComplexFunction1D('z');
        check(reFn(const Complex(3, 4))).equals(const Complex(3));
        check(imFn(const Complex(3, 4))).equals(const Complex(4));
        check(conjFn(const Complex(3, 4))).equals(const Complex(3, -4));
      },
    );

    test('toRectangular and toPolar normal forms', () {
      check(Expr.parse('(x + i * y)^2').toRectangular().toString())
          .equals('x ^ 2 - y ^ 2 + 2 * i * x * y');
      check(Expr.parse('exp(i * x)').toRectangular().toString())
          .equals('cos(x) + i * sin(x)');
      check(Expr.parse('1 / (x + i * y)').toRectangular().toString())
          .equals('x / (x ^ 2 + y ^ 2) - i * y / (x ^ 2 + y ^ 2)');

      check(Expr.parse('1 + i').toPolar().toString())
          .equals('sqrt(2) * exp(1/4 * i * pi)');
      check(Expr.parse('-2').toPolar().toString()).equals('2 * exp(i * pi)');
      check(Expr.parse('3').toPolar()).equals(IntegerNumber.of(3));
      check(Expr.parse('0').toPolar()).equals(IntegerNumber.zero);
    });
  });
}
