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

  group('VariableDomain equality and hashing', () {
    test('variables with distinct domains compare unequal', () {
      const x = Variable('x');
      const xPos1 = Variable('x', domain: VariableDomain.positive);
      const xPos2 = Variable('x', domain: VariableDomain.positive);
      check(x.domain).equals(VariableDomain.unknown);
      check(xPos1.domain).equals(VariableDomain.positive);
      check(x == xPos1).isFalse();
      check(xPos1 == xPos2).isTrue();
      check(xPos1.hashCode).equals(xPos2.hashCode);
    });
  });
}
