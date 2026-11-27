import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/normalize.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Structural expressionCost and pickCheapestExpr', () {
    test('ranks simpler canonical expressions strictly lower', () {
      const x = Variable('x');
      check(expressionCost(IntegerNumber.one)).equals(1);
      check(expressionCost(x) < expressionCost(x + IntegerNumber.one)).isTrue;
      check(expressionCost(x) < expressionCost(Fn.sin(x))).isTrue;
      check(expressionCost(Fn.sin(x)) < expressionCost(Fn.asin(x))).isTrue;

      final unsimp = Expr.parse('(x + 1)^2 - x^2 - 2*x');
      check(pickCheapestExpr(unsimp, [IntegerNumber.one]))
          .equals(IntegerNumber.one);
    });
  });

  group('Cost-driven normalization (normalize)', () {
    test('simplifies rational, expanded, and trigonometric identities without bloat', () {
      check(Expr.parse('(x^2 - 1) / (x - 1)').normalize().toString())
          .equals('1 + x');
      check(Expr.parse('(x + 1)^2 - x^2 - 2*x').normalize())
          .equals(IntegerNumber.one);
      check(Expr.parse('sin(x)^2 + cos(x)^2').normalize())
          .equals(IntegerNumber.one);

      // Compact factored/power form must not bloat into 11 expanded terms.
      final p10 = Expr.parse('(x + 1)^10');
      final normP10 = p10.normalize();
      check(expressionCost(normP10) <= expressionCost(p10.simplify())).isTrue;
      check(normP10).equals(p10.simplify());
    });

    test('scores OrderTerm, Relational, Piecewise, and BinderExpr nodes', () {
      const x = Variable('x');
      final orderCost = expressionCost(
        OrderTerm('x', 3, point: IntegerNumber.zero),
      );
      final relCost = expressionCost(Relational.lessThan(x, IntegerNumber.one));
      final pwCost = expressionCost(
        Piecewise([
          (relation: Relational.greaterThan(x, IntegerNumber.zero), expr: x),
        ], otherwise: IntegerNumber.zero),
      );
      final intCost = expressionCost(
        Integral(x, 'x', lower: IntegerNumber.zero, upper: IntegerNumber.one),
      );
      final derivCost = expressionCost(
        Derivative(x, 'x', point: IntegerNumber.one),
      );
      final limCost = expressionCost(Limit(x, 'x', IntegerNumber.zero));
      final sumCost = expressionCost(
        Sum(x, 'x', IntegerNumber.one, IntegerNumber.of(5)),
      );
      final rootSumCost = expressionCost(
        RootSum(x * x - IntegerNumber.two, 'x', x),
      );
      check(orderCost).isGreaterThan(1);
      check(relCost).isGreaterThan(4);
      check(pwCost).isGreaterThan(4);
      check(intCost).isGreaterThan(4);
      check(derivCost).isGreaterThan(4);
      check(limCost).isGreaterThan(4);
      check(sumCost).isGreaterThan(4);
      check(rootSumCost).isGreaterThan(5);
    });
  });
}
