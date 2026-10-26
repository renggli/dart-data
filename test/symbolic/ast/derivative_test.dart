import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Derivative construction and properties', () {
    test('constructs first and higher order derivatives', () {
      final d1 = Derivative(Sin(x), 'x');
      check(d1.expr).equals(Sin(x));
      check(d1.variable).equals('x');
      check(d1.order).equals(1);
      check(d1.isSimplified).isFalse();

      final d2 = Derivative(Sin(x), 'x', order: 2, isSimplified: true);
      check(d2.order).equals(2);
      check(d2.isSimplified).isTrue();
    });

    test('equality and hashCode', () {
      final a = Derivative(x + y, 'x', order: 2);
      final b = Derivative(x + y, 'x', order: 2);
      final c = Derivative(x + y, 'y', order: 2);
      final d = Derivative(x + y, 'x', order: 3);
      check(a).equals(b);
      check(a.hashCode).equals(b.hashCode);
      check(a == c).isFalse();
      check(a == d).isFalse();
    });
  });

  group('Derivative evaluation and tree operations', () {
    test('evaluate returns NaN', () {
      final d = Derivative(Sin(x), 'x');
      check(d.evaluate({'x': 1.0})).isNaN();
    });

    test('freeVariables and dependsOn', () {
      final d = Derivative(x * y, 'x');
      check(d.freeVariables).deepEquals({'x', 'y'});
      check(d.dependsOn('x')).isTrue();
      check(d.dependsOn('y')).isTrue();
      check(d.dependsOn('z')).isFalse();
    });

    test('substitute and mapChildren', () {
      final d = Derivative(x + y, 'x', order: 2);
      final sub = d.substitute('y', IntegerNumber.of(5));
      check(sub).equals(Derivative(x + IntegerNumber.of(5), 'x', order: 2));

      // Variable renaming with capture prevention
      final subVar = d.substitute('x', const Variable('z'));
      check(subVar).equals(Derivative(const Variable('z') + y, 'z', order: 2));

      // Non-variable replacement on differentiation variable evaluates the derivative
      final subConst = d.substitute('x', IntegerNumber.two);
      check(subConst).equals(IntegerNumber.zero);

      final mapped = d.mapChildren((child) => child * IntegerNumber.two);
      check(mapped)
          .equals(Derivative((x + y) * IntegerNumber.two, 'x', order: 2));
    });

    test('anyNode', () {
      final d = Derivative(Sin(x), 'x');
      check(d.anyNode((node) => node is Derivative)).isTrue();
      check(d.anyNode((node) => node is Sin)).isTrue();
      check(d.anyNode((node) => node is Cos)).isFalse();
    });

    test('point evaluation and alpha-renaming on variable capture', () {
      // Point evaluation of analytical derivative
      final dQuad = Derivative(x * x, 'x');
      final evalQuad = dQuad.substitute('x', IntegerNumber.two).simplify();
      check(evalQuad).equals(IntegerNumber.of(4));

      // Variable capture when replacing bound differentiation variable
      final dProduct = Derivative(x * y, 'x');
      final subRenamed = dProduct.substitute('x', y);
      check(subRenamed is Derivative).isTrue();
      final subD = subRenamed as Derivative;
      check(subD.variable).equals('y');
      // Free variable y was renamed to fresh y_1 to prevent capture
      check(subD.expr).equals(y * const Variable('y_1'));

      // Variable capture when substituting free variable with bound variable
      final subFree = dProduct.substitute('y', x);
      check(subFree is Derivative).isTrue();
      final subFreeD = subFree as Derivative;
      check(subFreeD.variable).equals('x_1');
      check(subFreeD.expr).equals(const Variable('x_1') * x);

      // Point evaluation for expressions without closed form derivative
      final dGamma = Derivative(Gamma(x), 'x');
      final subGamma = dGamma.substitute('x', IntegerNumber.two);
      check(subGamma)
          .equals(Derivative(Gamma(x), 'x', point: IntegerNumber.two));

      // Point properties: variable is bound, only point and other free variables remain
      final dPoint = Derivative(x * y, 'x', point: IntegerNumber.two);
      check(dPoint.dependsOn('x')).isFalse();
      check(dPoint.dependsOn('y')).isTrue();
      check(dPoint.freeVariables).deepEquals({'y'});

      // Simplify evaluates point derivative if possible
      final dPointQuad = Derivative(x * x, 'x', point: IntegerNumber.two);
      check(dPointQuad.simplify()).equals(IntegerNumber.of(4));

      // Substituting inside a Derivative with a point
      final dWithPoint = Derivative(x * y, 'x', point: y);
      final subPoint = dWithPoint.substitute('y', IntegerNumber.of(3));
      check(subPoint).equals(
        Derivative(x * IntegerNumber.of(3), 'x', point: IntegerNumber.of(3)),
      );
      check(Derivative(x * y, 'x', point: x).substitute('x', IntegerNumber.two))
          .equals(Derivative(x * y, 'x', point: IntegerNumber.two));
      final subPointCapture =
          Derivative(x * y, 'x', point: y).substitute('y', x) as Derivative;
      check(subPointCapture.variable).equals('x_1');
      check(subPointCapture.point).equals(x);
    });
  });
}
