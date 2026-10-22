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

      // Variable renaming
      final subVar = d.substitute('x', const Variable('z'));
      check(subVar).equals(Derivative(const Variable('z') + y, 'z', order: 2));

      // Non-variable replacement on differentiation variable is ignored to prevent point-eval bugs
      final subConst = d.substitute('x', IntegerNumber.two);
      check(subConst).equals(d);

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
  });
}
