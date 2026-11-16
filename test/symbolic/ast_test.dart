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

      // Free variables caching
      final free1 = expr1.freeVariables;
      final free2 = expr1.freeVariables;
      check(identical(free1, free2)).isTrue();
      check(free1).unorderedEquals(['x']);
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
      check(Pow(IntegerNumber.two, ComplexNumber.i).isReal).isFalse();
      check(Pow(IntegerNumber.two, IntegerNumber.two).isReal).isTrue();
    });

    test('supports substitute, mapChildren, getters, and isReal on special integral functions', () {
      const x = Variable('x');
      const y = Variable('y');
      const two = IntegerNumber.two;

      final unaryNodes = [
        Erfi(x),
        FresnelS(x),
        FresnelC(x),
        ExpIntegralEi(x),
        LogIntegralLi(x),
        SinIntegralSi(x),
        CosIntegralCi(x),
        SinhIntegralShi(x),
        CoshIntegralChi(x),
      ];
      for (final node in unaryNodes) {
        check(node.substitute('x', y)).equals(node.mapChildren((_) => y));
      }

      final ug = UpperGamma(x, y);
      check(ug.order).equals(x);
      check(ug.argument).equals(y);
      check(ug.substitute('x', two)).equals(UpperGamma(two, y));
      check(ug.mapChildren((c) => c == x ? two : c)).equals(UpperGamma(two, y));

      final lg = LowerGamma(x, y);
      check(lg.order).equals(x);
      check(lg.argument).equals(y);
      check(lg.substitute('x', two)).equals(LowerGamma(two, y));
      check(lg.mapChildren((c) => c == x ? two : c)).equals(LowerGamma(two, y));

      final pl = Polylog(x, y);
      check(pl.order).equals(x);
      check(pl.argument).equals(y);
      check(pl.substitute('x', two)).equals(Polylog(two, y));
      check(pl.mapChildren((c) => c == x ? two : c)).equals(Polylog(two, y));

      final ef = EllipticF(x, y);
      check(ef.amplitude).equals(x);
      check(ef.modulus).equals(y);
      check(ef.substitute('x', two)).equals(EllipticF(two, y));
      check(ef.mapChildren((c) => c == x ? two : c)).equals(EllipticF(two, y));

      final ee = EllipticEIncomplete(x, y);
      check(ee.amplitude).equals(x);
      check(ee.modulus).equals(y);
      check(ee.substitute('x', two)).equals(EllipticEIncomplete(two, y));
      check(ee.mapChildren((c) => c == x ? two : c))
          .equals(EllipticEIncomplete(two, y));

      // isReal branch cuts
      check(LogIntegralLi(two).isReal).isTrue();
      check(LogIntegralLi(IntegerNumber.negativeOne).isReal).isFalse();
      check(CosIntegralCi(two).isReal).isTrue();
      check(CosIntegralCi(IntegerNumber.zero).isReal).isFalse();
      check(CoshIntegralChi(two).isReal).isTrue();
      check(CoshIntegralChi(IntegerNumber.negativeOne).isReal).isFalse();
      check(Polylog(two, FractionNumber.half).isReal).isTrue();
      check(Polylog(two, two).isReal).isFalse();
      check(Polylog(two, Constant.pi).isReal).isFalse();
      check(CosIntegralCi(ComplexNumber.i).isReal).isFalse();
    });
  });
}
