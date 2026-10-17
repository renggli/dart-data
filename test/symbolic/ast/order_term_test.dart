import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('OrderTerm AST and asymptotic arithmetic', () {
    test('construction, properties, and equality', () {
      const o3 = OrderTerm('x', 3);
      check(o3.variable).equals('x');
      check(o3.order).equals(3);
      check(o3.point).equals(IntegerNumber.zero);
      check(o3.dependsOn('x')).isTrue();
      check(o3.dependsOn('y')).isFalse();
      check(o3.freeVariables).unorderedEquals(['x']);
      check(o3.evaluate({'x': 2.0})).equals(0.0);

      const shifted = OrderTerm('x', 2, point: IntegerNumber.one);
      check(shifted.point).equals(IntegerNumber.one);
      check(shifted.toString()).equals('O((x - 1)^2)');
    });

    test('additive and multiplicative absorption rules', () {
      const x = Variable('x');
      const o2 = OrderTerm('x', 2);
      const o4 = OrderTerm('x', 4);
      final x2 = Pow(x, IntegerNumber.two);
      final x3 = Pow(x, IntegerNumber.of(3));

      // O(x^2) + O(x^4) -> O(x^2)
      check((o2 + o4).simplify()).equals(o2);

      // 1 + x + x^2 + x^3 + O(x^2) -> 1 + x + O(x^2)
      check((IntegerNumber.one + x + x2 + x3 + o2).simplify())
          .equals(Add([IntegerNumber.one, x, o2]));

      // x * O(x^2) -> O(x^3)
      check((x * o2).simplify()).equals(const OrderTerm('x', 3));

      // x^2 * O(x^2) -> O(x^4)
      check((x2 * o2).simplify()).equals(o4);

      // O(x^2) * O(x^4) -> O(x^6)
      check((o2 * o4).simplify()).equals(const OrderTerm('x', 6));
    });
  });
}
