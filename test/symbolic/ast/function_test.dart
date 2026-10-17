import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
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
}
