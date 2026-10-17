import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('RelationalExpr AST', () {
    test('relational conditions evaluate, substitute, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      final lt = LessThan(x, IntegerNumber.zero);
      final le = LessEqual(x, IntegerNumber.zero);
      final gt = GreaterThan(x, IntegerNumber.zero);
      final ge = GreaterEqual(x, IntegerNumber.zero);
      final eq = Equal(x, IntegerNumber.zero);

      check(lt.evaluateCondition({'x': -1.0})).isTrue();
      check(lt.evaluateCondition({'x': 0.0})).isFalse();
      check(lt.evaluate({'x': -1.0})).equals(1.0);
      check(lt.evaluate({'x': 0.0})).equals(0.0);

      check(le.evaluateCondition({'x': 0.0})).isTrue();
      check(gt.evaluateCondition({'x': 1.0})).isTrue();
      check(ge.evaluateCondition({'x': 0.0})).isTrue();
      check(eq.evaluateCondition({'x': 0.0})).isTrue();

      for (final (node, build)
          in <(RelationalExpr, RelationalExpr Function(Expr, Expr))>[
            (lt, LessThan.new),
            (le, LessEqual.new),
            (gt, GreaterThan.new),
            (ge, GreaterEqual.new),
            (eq, Equal.new),
          ]) {
        check(node.substitute('x', y)).equals(build(y, IntegerNumber.zero));
        check(node.mapChildren((e) => e == x ? y : e))
            .equals(build(y, IntegerNumber.zero));
        check(node.freeVariables).unorderedEquals(['x']);
        check(node.dependsOn('x')).isTrue();
        check(node.dependsOn('y')).isFalse();
        check(node.anyNode((e) => e == x)).isTrue();
        check(node.hashCode).equals(build(x, IntegerNumber.zero).hashCode);
      }
    });
  });

  group('Piecewise AST', () {
    test('evaluation, freeVariables, dependsOn, substitute, mapChildren, and equality', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      final pw = Expr.parse('piecewise(x < -1, -1, x > 1, 1, x)');
      check(pw).isA<Piecewise>();
      check(pw.evaluate({'x': -5.0})).equals(-1.0);
      check(pw.evaluate({'x': 0.25})).equals(0.25);
      check(pw.evaluate({'x': 5.0})).equals(1.0);

      // Piecewise without otherwise returns NaN when no branch matches
      final partial = Piecewise([(LessThan(x, IntegerNumber.zero), y)]);
      check(partial.evaluate({'x': -1.0, 'y': 4.0})).equals(4.0);
      check(partial.evaluate({'x': 1.0, 'y': 4.0}).isNaN).isTrue();
      check(partial.freeVariables).unorderedEquals(['x', 'y']);
      check(partial.dependsOn('x')).isTrue();
      check(partial.dependsOn('y')).isTrue();
      check(partial.dependsOn('z')).isFalse();
      check(partial.mapChildren((e) => e)).equals(partial);
      check(partial.anyNode((e) => e == y)).isTrue();
      check(partial.anyNode((e) => e == z)).isFalse();

      final withOtherwise = Piecewise([
        (LessThan(x, IntegerNumber.zero), y),
      ], otherwise: z);
      check(withOtherwise.freeVariables).unorderedEquals(['x', 'y', 'z']);
      check(withOtherwise.dependsOn('z')).isTrue();
      check(withOtherwise.mapChildren((e) => e)).equals(withOtherwise);
      check(withOtherwise.anyNode((e) => e == withOtherwise)).isTrue();
      check(withOtherwise.anyNode((e) => e == z)).isTrue();
      check(withOtherwise == partial).isFalse();
      check(
        withOtherwise ==
            Piecewise([(LessThan(x, IntegerNumber.zero), x)], otherwise: z),
      ).isFalse();

      // Substituting a constant collapses to the matching branch
      check(pw.substitute('x', IntegerNumber.of(-3)).simplify())
          .equals(IntegerNumber.negativeOne);
      check(pw.substitute('x', IntegerNumber.of(0)).simplify())
          .equals(IntegerNumber.zero);
      check(pw.substitute('x', IntegerNumber.of(3)).simplify())
          .equals(IntegerNumber.one);
    });
  });
}
