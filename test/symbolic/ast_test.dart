import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('AST composition and equality', () {
    test('constructs composite expressions across all AST node families', () {
      const x = Variable('x');
      final expr =
          Fn.sin(x) +
          Fn.cos(x) * IntegerNumber.two -
          Pow.of(x, IntegerNumber.two);
      check(expr.freeVariables).unorderedEquals(['x']);
      check(expr.dependsOn('x')).isTrue;
      check(expr.dependsOn('y')).isFalse;
    });

    test('cached structural hashCode and equality across composite trees', () {
      final expr1 = Expr.parse('sin(x^2 + 1) + 3 * x * cos(x)');
      final expr2 = Expr.parse('sin(x^2 + 1) + 3 * x * cos(x)');
      check(expr1.hashCode).equals(expr2.hashCode);
      check(expr1).equals(expr2);

      // Free variables caching
      final free1 = expr1.freeVariables;
      final free2 = expr1.freeVariables;
      check(identical(free1, free2)).isTrue;
      check(free1).unorderedEquals(['x']);
    });
  });

  group('AST substitution and child mapping', () {
    test('substitutes variables and transforms direct children', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = Add.of([
        x,
        Mul.of([IntegerNumber.two, y]),
      ]);
      final sub = expr.substitute('x', IntegerNumber.of(5));
      check(sub.evaluate({'y': 3.0})).equals(11.0);
    });

    test('evaluates isReal across calculus, piecewise, and function nodes', () {
      const x = Variable('x');
      check(
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        ], otherwise: x).isReal,
      ).isTrue;
      check(
        Integral(
          x,
          'x',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.one,
        ).isReal,
      ).isTrue;
      check(Derivative(x, 'x').isReal).isTrue;
      check(Limit(x, 'x', IntegerNumber.zero).isReal).isTrue;
      check(Sum(x, 'x', IntegerNumber.one, const Variable('n')).isReal).isTrue;
      check(Product(x, 'x', IntegerNumber.one, const Variable('n')).isReal)
          .isTrue;
      check(Fn.symbolic('f', const [x]).isReal).isTrue;
      check(Pow.of(IntegerNumber.two, ComplexNumber.i).isReal).isFalse;
      check(Pow.of(IntegerNumber.two, IntegerNumber.two).isReal).isTrue;
    });

    test('supports substitute, mapChildren, getters, and isReal on special integral functions', () {
      const x = Variable('x');
      const y = Variable('y');
      final two = IntegerNumber.two;

      final unaryNodes = [
        Fn.erfi(x),
        Fn.fresnelS(x),
        Fn.fresnelC(x),
        Fn.ei(x),
        Fn.li(x),
        Fn.si(x),
        Fn.ci(x),
        Fn.shi(x),
        Fn.chi(x),
      ];
      for (final node in unaryNodes) {
        check(node.substitute('x', y)).equals(node.mapChildren((_) => y));
      }

      final ug = Fn.upperGamma(x, y);
      check(ug.args[0]).equals(x);
      check(ug.args[1]).equals(y);
      check(ug.substitute('x', two)).equals(Fn.upperGamma(two, y));
      check(ug.mapChildren((c) => c == x ? two : c))
          .equals(Fn.upperGamma(two, y));

      final lg = Fn.lowerGamma(x, y);
      check(lg.args[0]).equals(x);
      check(lg.args[1]).equals(y);
      check(lg.substitute('x', two)).equals(Fn.lowerGamma(two, y));
      check(lg.mapChildren((c) => c == x ? two : c))
          .equals(Fn.lowerGamma(two, y));

      final pl = Fn.polylog(x, y);
      check(pl.args[0]).equals(x);
      check(pl.args[1]).equals(y);
      check(pl.substitute('x', two)).equals(Fn.polylog(two, y));
      check(pl.mapChildren((c) => c == x ? two : c)).equals(Fn.polylog(two, y));

      final ef = Fn.ellipticF(x, y);
      check(ef.args[0]).equals(x);
      check(ef.args[1]).equals(y);
      check(ef.substitute('x', two)).equals(Fn.ellipticF(two, y));
      check(ef.mapChildren((c) => c == x ? two : c))
          .equals(Fn.ellipticF(two, y));

      final ee = Fn.ellipticE(x, y);
      check(ee.args[0]).equals(x);
      check(ee.args[1]).equals(y);
      check(ee.substitute('x', two)).equals(Fn.ellipticE(two, y));
      check(ee.mapChildren((c) => c == x ? two : c))
          .equals(Fn.ellipticE(two, y));

      // isReal branch cuts
      check(Fn.li(two).isReal).isTrue;
      check(Fn.li(IntegerNumber.negativeOne).isReal).isFalse;
      check(Fn.ci(two).isReal).isTrue;
      check(Fn.ci(IntegerNumber.zero).isReal).isFalse;
      check(Fn.chi(two).isReal).isTrue;
      check(Fn.chi(IntegerNumber.negativeOne).isReal).isFalse;
      check(Fn.polylog(two, FractionNumber.half).isReal).isTrue;
      check(Fn.polylog(two, two).isReal).isFalse;
      check(Fn.polylog(two, Constant.pi).isReal).isFalse;
      check(Fn.ci(ComplexNumber.i).isReal).isFalse;
    });
  });
}
