import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('AST composition and equality', () {
    test('constructs composite expressions across all AST node families', () {
      const x = Variable('x');
      final expr =
          Sin(x) + Cos(x) * IntegerNumber.two - Pow(x, IntegerNumber.two);
      check(expr.freeVariables).unorderedEquals(['x']);
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('y')).isFalse();
    });

    test('cached structural hashCode and equality across composite trees', () {
      final expr1 = Expr.parse('sin(x^2 + 1) + 3 * x * cos(x)');
      final expr2 = Expr.parse('sin(x^2 + 1) + 3 * x * cos(x)');
      check(expr1.hashCode).equals(expr2.hashCode);
      check(expr1).equals(expr2);
    });
  });

  group('AST substitution and child mapping', () {
    test('substitutes variables and transforms direct children', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = Add([
        x,
        Mul([IntegerNumber.two, y]),
      ]);
      final sub = expr.substitute('x', IntegerNumber.of(5));
      check(sub.evaluate({'y': 3.0})).equals(11.0);
    });

    test('evaluates isReal across calculus, piecewise, and function nodes', () {
      const x = Variable('x');
      check(
        Piecewise([
          (relation: LessThan(x, IntegerNumber.zero), expr: -x),
        ], otherwise: x).isReal,
      ).isTrue();
      check(
        Integral(
          x,
          'x',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.one,
        ).isReal,
      ).isTrue();
      check(Derivative(x, 'x').isReal).isTrue();
      check(Limit(x, 'x', IntegerNumber.zero).isReal).isTrue();
      check(Sum(x, 'x', IntegerNumber.one, const Variable('n')).isReal)
          .isTrue();
      check(Product(x, 'x', IntegerNumber.one, const Variable('n')).isReal)
          .isTrue();
      check(VariableFunction('f', const [x]).isReal).isTrue();
    });
  });
}
