import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('RelationalExpr and Piecewise AST', () {
    test('relational conditions evaluate and simplify constants', () {
      const x = Variable('x');
      final lt = LessThan(x, IntegerNumber.zero);
      final le = LessEqual(x, IntegerNumber.zero);
      final gt = GreaterThan(x, IntegerNumber.zero);
      final ge = GreaterEqual(x, IntegerNumber.zero);
      final eq = Equal(x, IntegerNumber.zero);

      check(lt.evaluateCondition({'x': -1.0})).isTrue();
      check(lt.evaluateCondition({'x': 0.0})).isFalse();
      check(le.evaluateCondition({'x': 0.0})).isTrue();
      check(gt.evaluateCondition({'x': 1.0})).isTrue();
      check(ge.evaluateCondition({'x': 0.0})).isTrue();
      check(eq.evaluateCondition({'x': 0.0})).isTrue();
    });

    test('Piecewise evaluation, simplification, and substitution', () {
      final pw = Expr.parse('piecewise(x < -1, -1, x > 1, 1, x)');
      check(pw).isA<Piecewise>();
      check(pw.evaluate({'x': -5.0})).equals(-1.0);
      check(pw.evaluate({'x': 0.25})).equals(0.25);
      check(pw.evaluate({'x': 5.0})).equals(1.0);

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
