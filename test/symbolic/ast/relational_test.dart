import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Relational AST', () {
    test('relational conditions evaluate, substitute, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      final lt = Relational.lessThan(x, IntegerNumber.zero);
      final le = Relational.lessEqual(x, IntegerNumber.zero);
      final gt = Relational.greaterThan(x, IntegerNumber.zero);
      final ge = Relational.greaterEqual(x, IntegerNumber.zero);
      final eq = Relational.equal(x, IntegerNumber.zero);
      final ne = Relational.notEqual(x, IntegerNumber.zero);

      check(lt.evaluate({'x': -1.0})).equals(1.0);
      check(lt.evaluate({'x': 0.0})).equals(0.0);

      check(le.evaluate({'x': 0.0})).equals(1.0);
      check(gt.evaluate({'x': 1.0})).equals(1.0);
      check(ge.evaluate({'x': 0.0})).equals(1.0);
      check(eq.evaluate({'x': 0.0})).equals(1.0);
      check(ne.evaluate({'x': 1.0})).equals(1.0);
      check(ne.evaluate({'x': 0.0})).equals(0.0);

      for (final (node, build)
          in <(Relational, Relational Function(Expr, Expr))>[
            (lt, Relational.lessThan),
            (le, Relational.lessEqual),
            (gt, Relational.greaterThan),
            (ge, Relational.greaterEqual),
            (eq, Relational.equal),
            (ne, Relational.notEqual),
          ]) {
        check(node.substitute('x', y)).equals(build(y, IntegerNumber.zero));
        check(node.mapChildren((e) => e == x ? y : e))
            .equals(build(y, IntegerNumber.zero));
        check(node.freeVariables).unorderedEquals(['x']);
        check(node.dependsOn('x')).isTrue;
        check(node.dependsOn('y')).isFalse;
        check(node.anyNode((e) => e == x)).isTrue;
        check(node.hashCode).equals(build(x, IntegerNumber.zero).hashCode);
      }
    });
  });
}
