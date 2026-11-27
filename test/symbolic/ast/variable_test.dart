import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Variable properties and evaluation', () {
    test('evaluation, freeVariables, dependsOn, and substitute', () {
      const x = Variable('x');
      const y = Variable('y');
      check(() => x.evaluate({})).throws<ArgumentError>();
      check(x.evaluate({'x': 4.5})).equals(4.5);
      check(x.mapChildren((e) => y)).equals(x);
      check(x.anyNode((e) => e == x)).isTrue;

      final expr = x * y + Fn.sin(x);
      check(expr.freeVariables).unorderedEquals(['x', 'y']);
      check(expr.dependsOn('x')).isTrue;
      check(expr.dependsOn('z')).isFalse;

      final sub = expr.substitute('x', IntegerNumber.one);
      check(sub.freeVariables).unorderedEquals(['y']);
      check(sub.evaluate({'y': 5.0})).isCloseTo(5.0 + math.sin(1.0), 1e-12);
    });
  });

  group('Variable equality and hashing', () {
    test('variables with identical names compare equal', () {
      const x1 = Variable('x');
      const x2 = Variable('x');
      const y = Variable('y');
      check(x1 == x2).isTrue;
      check(x1 == y).isFalse;
      check(x1.hashCode).equals(x2.hashCode);
      check(Assumptions.none.domainOf('x')).equals(VariableDomain.unknown);
      check(
        const Assumptions(domains: {'x': VariableDomain.positive})
            .domainOf('x'),
      ).equals(VariableDomain.positive);
    });
  });

  group('Symbolic Call AST node', () {
    test('parsing, formatting, simplification, substitution, and evaluation errors', () {
      const x = Variable('x');
      const y = Variable('y');
      final f = Expr.parse('f(x + x, y)');
      check(f).equals(Fn.symbolic('f', [IntegerNumber.two * x, y]));
      check(f.toString()).equals('f(2 * x, y)');
      check(f.toLatex()).equals('f(2 x, y)');
      check(f.toMathMl(root: false)).equals(
        '<mrow><mi>f</mi><mo>(</mo><mrow><mn>2</mn><mi>x</mi></mrow><mo>,</mo><mi>y</mi><mo>)</mo></mrow>',
      );
      check(f.freeVariables).unorderedEquals(['x', 'y']);
      check(f.dependsOn('x')).isTrue;
      check(f.dependsOn('z')).isFalse;
      check(f.anyNode((e) => e == y)).isTrue;

      final simplified = f.simplify();
      check(simplified).equals(
        Fn.symbolic('f', [
          Mul.of([IntegerNumber.two, x]),
          y,
        ]),
      );
      check(simplified.hashCode).equals(
        Fn.symbolic('f', [
          Mul.of([IntegerNumber.two, x]),
          y,
        ]).hashCode,
      );

      final sub = simplified.substitute('y', IntegerNumber.one);
      check(sub.toString()).equals('f(2 * x, 1)');

      check(() => simplified.evaluate({'x': 1.0, 'y': 2.0}))
          .throws<UnsupportedError>();
      check(simplified.evaluateComplex).throws<UnsupportedError>();
      check(simplified.derivative('x')).equals(Derivative(simplified, 'x'));
      check(() => simplified.toFunction1D('x')).throws<UnsupportedError>();
    });
  });
}
