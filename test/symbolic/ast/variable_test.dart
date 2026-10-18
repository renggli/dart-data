import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Variable properties and evaluation', () {
    test('evaluation, freeVariables, dependsOn, and substitute', () {
      const x = Variable('x');
      const y = Variable('y');
      check(x.isSimplified).isTrue();
      check(() => x.evaluate({})).throws<ArgumentError>();
      check(x.evaluate({'x': 4.5})).equals(4.5);
      check(x.mapChildren((e) => y)).equals(x);
      check(x.anyNode((e) => e == x)).isTrue();

      final expr = x * y + Sin(x);
      check(expr.freeVariables).unorderedEquals(['x', 'y']);
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('z')).isFalse();

      final sub = expr.substitute('x', IntegerNumber.zero);
      check(sub.freeVariables).unorderedEquals(['y']);
      check(sub.evaluate({'y': 5.0})).equals(0.0);
    });
  });

  group('Variable equality and hashing', () {
    test('variables with identical names compare equal', () {
      const x1 = Variable('x');
      const x2 = Variable('x');
      const y = Variable('y');
      check(x1 == x2).isTrue();
      check(x1 == y).isFalse();
      check(x1.hashCode).equals(x2.hashCode);
      check(Assumptions.none.domainOf('x')).equals(VariableDomain.unknown);
      check(
        const Assumptions(domains: {'x': VariableDomain.positive})
            .domainOf('x'),
      ).equals(VariableDomain.positive);
    });
  });

  group('VariableFunction AST node', () {
    test('parsing, formatting, simplification, substitution, and evaluation errors', () {
      const x = Variable('x');
      const y = Variable('y');
      final f = Expr.parse('f(x + x, y)');
      check(f).equals(VariableFunction('f', [x + x, y]));
      check(f.isSimplified).isFalse();
      check(f.toString()).equals('f(x + x, y)');
      check(f.toLatex()).equals('f(x + x, y)');
      check(f.toMathMl(root: false)).equals(
        '<mrow><mi>f</mi><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>x</mi></mrow><mo>,</mo><mi>y</mi><mo>)</mo></mrow>',
      );
      check(f.freeVariables).unorderedEquals(['x', 'y']);
      check(f.dependsOn('x')).isTrue();
      check(f.dependsOn('z')).isFalse();
      check(f.anyNode((e) => e == y)).isTrue();

      final simplified = f.simplify();
      check(simplified).equals(
        VariableFunction('f', [
          Mul([IntegerNumber.two, x]),
          y,
        ], isSimplified: true),
      );
      check(simplified.isSimplified).isTrue();
      check(simplified.hashCode).equals(
        VariableFunction('f', [
          Mul([IntegerNumber.two, x]),
          y,
        ]).hashCode,
      );

      final sub = simplified.substitute('y', IntegerNumber.one);
      check(sub.toString()).equals('f(2 * x, 1)');

      check(() => simplified.evaluate({'x': 1.0, 'y': 2.0}))
          .throws<UnsupportedError>();
      check(simplified.evaluateComplex).throws<UnsupportedError>();
      check(simplified.derivative('x'))
          .equals(Derivative(simplified, 'x', isSimplified: true));
      check(simplified.compileBytecode).throws<UnsupportedError>();
    });
  });
}
